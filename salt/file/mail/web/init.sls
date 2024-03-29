# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


{% from 'accounts/client/map.jinja' import accounts_client %}
{% from 'acme/map.jinja' import acme, acme_cert %}
{% from 'apache_httpd/map.jinja' import apache_httpd %}
{% from 'common/map.jinja' import common %}
{% from 'crypto/map.jinja' import crypto %}
{% from 'mail/map.jinja' import mail %}
{% from 'mail/web/map.jinja' import mail_web %}
{% from 'php/map.jinja' import php %}
{% from 'stunnel/map.jinja' import stunnel %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- accounts.client
- acme
- apache_httpd
- apache_httpd.acme_hooks
- apache_httpd.expires
- apache_httpd.https
- apache_httpd.php
- apache_httpd.rewrite
- stunnel
- virtual_machine.guest


mail_web_pkgs:
  pkg.installed:
  - pkgs: {{ mail_web.pkgs | tojson }}
  - require:
    - apache_httpd_pkgs
    - apache_httpd_php_pkgs


{{ acme_cert(pillar.mail.web.name) }}


{{ accounts_client.oauth2_client_secret_file(pillar.mail.web.name) }}


# TODO(https://bugs.php.net/bug.php?id=81528): Have roundcube connect directly
# to these services instead of going through stunnel.
{{ stunnel.instance(
    instance_name='imap',
    client=True,
    level='strict',
    accept='localhost:143',
    peer_certs=pillar.mail.common.storage.certificate_by_minion.values(),
    connect=pillar.mail.common.storage.name + ':993',
) }}
{{ stunnel.instance(
    instance_name='submission',
    client=True,
    level='strict',
    accept='localhost:587',
    peer_certs=pillar.mail.common.outbound.certificates,
    connect=pillar.mail.common.outbound.name + ':465',
) }}


/var/local/roundcube/database:
  file.directory:
  - user: {{ apache_httpd.user }}
  - group: {{ apache_httpd.group }}
  - dir_mode: 0700
  - require:
    - /var/local/roundcube is mounted
    - /var/local/roundcube is backed up
    - apache_httpd_pkgs

{{ common.local_lib }}/roundcube-generate-dynamic-config:
  file.managed:
  - source: salt://mail/web/generate_dynamic_config.py
  - mode: 0755

# TODO(roundcube > 1.5-rc): Switch to an authenticated encryption mode.
{% load_yaml as roundcube_generate_dynamic_config %}
>-
  {{ common.local_lib }}/roundcube-generate-dynamic-config
  --key-bits={{ crypto.openssl.unauthenticated_symmetric_key_bits }}
  --cipher-method={{ crypto.openssl.unauthenticated_symmetric_cipher }}
  --group={{ apache_httpd.group }}
  --output={{ mail_web.config_dir }}/config-dynamic.inc.php
{% endload %}
{{ mail_web.config_dir }}/config-dynamic.inc.php:
  cmd.run:
  - name: {{ roundcube_generate_dynamic_config | tojson }}
  - require:
    - mail_web_pkgs
  - onchanges:
    - {{ common.local_lib }}/roundcube-generate-dynamic-config
  - watch_in:
    - apache_httpd_running
  cron.present:
  - name: >-
      {{ roundcube_generate_dynamic_config }}
      &&
      systemctl reload-or-restart {{ apache_httpd.service }}
  - identifier: ac3e840f-8148-4868-a1a5-2ec39830fa3f
  - minute: random
  - hour: random
  - daymonth: random
  - require:
    - cmd: {{ mail_web.config_dir }}/config-dynamic.inc.php

{{ mail_web.config_dir }}/config.inc.php:
  file.managed:
  - source: salt://mail/web/config.inc.php.jinja
  - user: root
  - group: {{ apache_httpd.group }}
  - mode: 0640
  - template: jinja
  - require:
    - mail_web_pkgs
    - /var/local/roundcube/database
    - {{ accounts_client.oauth2_client_secret_filename(pillar.mail.web.name) }} exists
    - {{ mail_web.config_dir }}/config-dynamic.inc.php
  - watch_in:
    - apache_httpd_running

roundcube database migrations:
  cmd.run:
  - name: >-
      {{ mail_web.static_root }}/bin/updatedb.sh
      --package=roundcube
      --dir={{ mail_web.static_root }}/SQL
  - runas: {{ apache_httpd.user }}
  - env:
      RCUBE_CONFIG_PATH: {{ mail_web.config_dir }}
  - require:
    - /var/local/roundcube/database
    - {{ mail_web.config_dir }}/config.inc.php
    - mail_web_pkgs
  - onlyif:
    - fun: file.file_exists
      args:
      - /var/local/roundcube/database/roundcube.db
    - fun: file.file_exists
      args:
      - /var/local/roundcube/database/version
    - fun: pkg.version_cmp
      args:
      - __slot__:salt:pkg.version({{ mail_web.main_pkg }})
      - __slot__:salt:file.read(/var/local/roundcube/database/version)
  file.managed:
  - name: /var/local/roundcube/database/version
  - contents: __slot__:salt:pkg.version({{ mail_web.main_pkg }})
  - contents_newline: false
  - require:
    - cmd: roundcube database migrations


{{ apache_httpd.config_dir }}/sites-enabled/{{ pillar.mail.web.name }}.conf:
  file.managed:
  - contents: |
      <VirtualHost *:443>
        ServerName {{ pillar.mail.web.name }}

        {{ apache_httpd.port_mux_vhost_config() | indent(8) }}

        {{ apache_httpd.https_vhost_config(
            fullchain=(
                acme.certbot_config_dir + '/live/' + pillar.mail.web.name +
                '/fullchain.pem'),
            privkey=(
                acme.certbot_config_dir + '/live/' + pillar.mail.web.name +
                '/privkey.pem'),
        ) | indent(8) }}

        Include {{ php.mod_php_conf }}

        # Allow uploading larger attachments.
        php_value post_max_size {{ mail.message_size_limit_bytes }}
        php_value upload_max_filesize {{ mail.message_size_limit_bytes }}

        DocumentRoot {{ mail_web.document_root }}
        Include {{ mail_web.config_dir }}/apache.conf
      </VirtualHost>
  - require:
    - {{ apache_httpd.config_dir }}/sites-enabled exists
    - mail_web_pkgs
    - {{ acme.certbot_config_dir }}/live/{{ pillar.mail.web.name }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ pillar.mail.web.name }}/privkey.pem
    - {{ mail_web.config_dir }}/config.inc.php
    - roundcube database migrations
  - require_in:
    - {{ apache_httpd.config_dir }}/sites-enabled is clean
  - watch_in:
    - apache_httpd_running

{{ apache_httpd.config_dir }}/conf-enabled/roundcube.conf:
  file.managed:
  - contents: |
      # The Debian package re-creates a symlink at this path on every upgrade.
      # This file exists to prevent that from happening.
  - follow_symlinks: false
  - require:
    - {{ apache_httpd.config_dir }}/conf-enabled exists
  - require_in:
    - {{ apache_httpd.config_dir }}/conf-enabled is clean
  - watch_in:
    - apache_httpd_running
