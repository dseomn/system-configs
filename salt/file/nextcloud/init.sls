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


{% from 'acme/map.jinja' import acme, acme_cert %}
{% from 'apache_httpd/map.jinja' import apache_httpd %}
{% from 'common/map.jinja' import common %}
{% from 'nextcloud/map.jinja' import nextcloud %}
{% from 'php/map.jinja' import php %}


# Something hopefully close to a list of the apps enabled by default. (I wasn't
# sure how to find the exact list.)
{% set apps_default = [
    'accessibility',
    'activity',
    'admin_audit',
    'cloud_federation_api',
    'comments',
    'contactsinteraction',
    'dashboard',
    'dav',
    'encryption',
    'federatedfilesharing',
    'federation',
    'files',
    'files_external',
    'files_sharing',
    'files_trashbin',
    'files_versions',
    'firstrunwizard',
    'lookup_server_connector',
    'nextcloud_announcements',
    'notifications',
    'oauth2',
    'password_policy',
    'privacy',
    'provisioning_api',
    'recommendations',
    'serverinfo',
    'settings',
    'sharebymail',
    'support',
    'survey_client',
    'systemtags',
    'text',
    'theming',
    'twofactor_backupcodes',
    'updatenotification',
    'user_ldap',
    'user_status',
    'viewer',
    'weather_status',
    'workflowengine',
] %}

# Non-default apps managed by this file.
{% set apps_managed = [] %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- acme
- apache_httpd
- apache_httpd.acme_hooks
- apache_httpd.https
- apache_httpd.php
- apache_httpd.rewrite
- virtual_machine.guest


nextcloud_pkgs:
  pkg.installed:
  - pkgs: {{ nextcloud.pkgs | tojson }}


{{ php.config_dir }}/cli/conf.d/90-nextcloud.ini:
  file.managed:
  - contents: |
      ; https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/caching_configuration.html#id1
      apc.enable_cli=1
  - require:
    - nextcloud_pkgs


{{ acme_cert(pillar.nextcloud.name) }}


/var/local/nextcloud/data:
  file.directory:
  - user: {{ apache_httpd.user }}
  - group: {{ apache_httpd.group }}
  - dir_mode: 0700
  - require:
    - /var/local/nextcloud is mounted
    - /var/local/nextcloud is backed up
    - apache_httpd_pkgs

/var/local/nextcloud/webroot:
  file.directory:
  - user: {{ apache_httpd.user }}
  - group: {{ apache_httpd.group }}
  - dir_mode: 0700
  - require:
    - /var/local/nextcloud is mounted
    - /var/local/nextcloud is backed up
    - apache_httpd_pkgs

/var/cache/nextcloud:
  file.directory:
  - user: {{ apache_httpd.user }}
  - group: {{ apache_httpd.group }}
  - dir_mode: 0700
  - require:
    - apache_httpd_pkgs

{% set occ = '/var/local/nextcloud/webroot/occ' %}

# Nextcloud is kinda tricky to fully manage with salt, so require it to be
# either restored from a backup or installed manually.
nextcloud_installed:
  file.exists:
  - name: {{ occ }}
  - require:
    - /var/local/nextcloud/data
    - /var/local/nextcloud/webroot
    - /var/cache/nextcloud

{% do apps_managed.append('apporder') %}
/var/local/nextcloud/webroot/config/local.config.php:
  file.managed:
  - source: salt://nextcloud/config.php.jinja
  - user: root
  - group: {{ apache_httpd.group }}
  - mode: 0640
  - template: jinja
  - require:
    - nextcloud_installed

nextcloud_usable:
  test.nop:
  - require:
    - nextcloud_installed
    - /var/local/nextcloud/webroot/config/local.config.php
    - {{ php.config_dir }}/cli/conf.d/90-nextcloud.ini

# https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html#pretty-urls
{{ php.bin }} {{ occ }} maintenance:update:htaccess:
  cmd.run:
  - runas: {{ apache_httpd.user }}
  - require:
    - nextcloud_usable
  - onchanges:
    - /var/local/nextcloud/webroot/config/local.config.php

/var/local/nextcloud/hostname:
  file.managed:
  - contents: {{ grains.id | tojson }}
  - require:
    - /var/local/nextcloud is mounted
    - /var/local/nextcloud is backed up
    - nextcloud_usable

# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/restore.html#restoring-backup
{{ php.bin }} {{ occ }} maintenance:data-fingerprint:
  cmd.run:
  - runas: {{ apache_httpd.user }}
  - onchanges:
    - /var/local/nextcloud/hostname

# https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html#cron
{{ php.bin }} -f /var/local/nextcloud/webroot/cron.php:
  cron.present:
  - user: {{ apache_httpd.user }}
  - identifier: a714d4d0-42d7-4cc3-a994-90da6e98b45b
  - minute: '*/5'
  - require:
    - nextcloud_usable

# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/update.html#batch-mode-for-command-line-based-updater
# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/upgrade.html#long-running-migration-steps
upgrade_nextcloud:
  cron.present:
  - name: >-
      {{ php.bin }}
      {{ occ }}
      app:update
      --quiet
      --all
      &&
      {{ php.bin }}
      /var/local/nextcloud/webroot/updater/updater.phar
      --no-interaction
      --quiet
      &&
      {{ php.bin }}
      {{ occ }}
      db:add-missing-columns
      --quiet
      &&
      {{ php.bin }}
      {{ occ }}
      db:add-missing-indices
      --quiet
  - user: {{ apache_httpd.user }}
  - identifier: db4ae9a2-802e-490d-884f-5a6e86ce3db9
  - minute: random
  - hour: random
  - require:
    - nextcloud_usable


{% if not salt.file.file_exists(occ) %}

re-run state.apply to manage Nextcloud apps:
  test.fail_without_changes: []

{% else %}

{% set apps = salt.cmd.run_stdout(
    php.bin + ' ' + occ + ' app:list --output=json',
    runas=apache_httpd.user,
) | load_json %}
{% set apps_desired =
    (apps_default + apps_managed + pillar.nextcloud.apps.enabled)
    | reject('in', pillar.nextcloud.apps.disabled)
    | unique
%}

{% for app in apps_desired %}
{% if app in apps.enabled %}
{% do apps.enabled.pop(app) %}
{% elif app in apps.disabled %}
{{ php.bin }} {{ occ }} app:enable {{ app }}:
  cmd.run:
  - runas: {{ apache_httpd.user }}
  - require:
    - nextcloud_usable
{% else %}
{{ php.bin }} {{ occ }} app:install {{ app }}:
  cmd.run:
  - runas: {{ apache_httpd.user }}
  - require:
    - nextcloud_usable
{% endif %}
{% endfor %}

{% for app in apps.enabled %}
{{ php.bin }} {{ occ }} app:disable {{ app }}:
  cmd.run:
  - runas: {{ apache_httpd.user }}
  - require:
    - nextcloud_usable
{% endfor %}

{% endif %}


{{ apache_httpd.config_dir }}/sites-enabled/{{ pillar.nextcloud.name }}.conf:
  file.managed:
  - contents: |
      <VirtualHost *:443>
        ServerName {{ pillar.nextcloud.name }}

        {{ apache_httpd.port_mux_vhost_config() | indent(8) }}

        {{ apache_httpd.https_vhost_config(
            fullchain=(
                acme.certbot_config_dir + '/live/' + pillar.nextcloud.name +
                '/fullchain.pem'),
            privkey=(
                acme.certbot_config_dir + '/live/' + pillar.nextcloud.name +
                '/privkey.pem'),
        ) | indent(8) }}

        # https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html#serve-security-related-headers-by-the-web-server
        Header always set X-Content-Type-Options nosniff
        Header always set X-XSS-Protection "1; mode=block"
        Header always set X-Robots-Tag none
        Header always set X-Frame-Options SAMEORIGIN
        Header always set Referrer-Policy no-referrer

        Include {{ php.mod_php_conf }}

        # https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html#apache-web-server-configuration
        DocumentRoot /var/local/nextcloud/webroot
        <Directory /var/local/nextcloud/webroot>
          Require all granted
          AllowOverride All
          Options FollowSymLinks MultiViews
        </Directory>
      </VirtualHost>
  - require:
    - {{ apache_httpd.config_dir }}/sites-enabled exists
    - nextcloud_pkgs
    - {{ acme.certbot_config_dir }}/live/{{ pillar.nextcloud.name }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ pillar.nextcloud.name }}/privkey.pem
    - nextcloud_usable
  - require_in:
    - {{ apache_httpd.config_dir }}/sites-enabled is clean
  - watch_in:
    - apache_httpd_running
