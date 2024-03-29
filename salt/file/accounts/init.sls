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


{% from 'accounts/map.jinja' import accounts %}
{% from 'acme/map.jinja' import acme, acme_cert %}
{% from 'apache_httpd/map.jinja' import apache_httpd %}
{% from 'common/map.jinja' import common %}
{% from 'crypto/map.jinja' import crypto %}


{#
 # DBD::CSV uses Text::CSV_XS. Documentation:
 # https://metacpan.org/pod/Text::CSV_XS#SPECIFICATION
 #}
{% macro csv_line() -%}
  {%- for value in varargs -%}
    {{- '"' + value.replace('"', '""') + '"' -}}
    {{- '' if loop.last else ',' -}}
  {%- endfor -%}
{%- endmacro %}


include:
- acme
- apache_httpd
- apache_httpd.acme_hooks
- apache_httpd.expires
- apache_httpd.fcgid
- apache_httpd.https
- apache_httpd.mpm_default
- apache_httpd.rewrite
- crypto.secret_rotation


accounts_pkgs:
  pkg.installed:
  - pkgs: {{ accounts.pkgs | tojson }}
  - require:
    # liblemonldap-ng-portal-perl depends on one of a few options, including
    # Apache HTTPd. Install that first so that the other options aren't
    # installed unnecessarily.
    - apache_httpd_pkgs


{{ acme_cert(pillar.accounts.name) }}


{{ accounts.llng_config_dir }}/auth.passwd:
  file.managed:
  - source: salt://accounts/auth.passwd.jinja
  - group: {{ apache_httpd.group }}
  - mode: 0640
  - template: jinja
  - require:
    - accounts_pkgs
  test.configurable_test_state:
  - warnings: >-
      Some users don't have a password set. Run `mkpasswd` to generate a crypted
      password.
  - require:
    - file: {{ accounts.llng_config_dir }}/auth.passwd
  - onlyif:
    - grep ':!$' {{ accounts.llng_config_dir }}/auth.passwd

/etc/pam.d/lemonldap-ng:
  file.managed:
  - contents: |
      account required pam_permit.so
      auth optional pam_faildelay.so delay={{ 1_000_000 }}
      auth required pam_pwdfile.so pwdfile={{ accounts.llng_config_dir }}/auth.passwd
      password required pam_deny.so
      session required pam_deny.so
  - require:
    - accounts_pkgs
    - {{ accounts.llng_config_dir }}/auth.passwd


# TODO(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=995949): Remove this.
# user/group/dir_mode are from LMCACHEDIR in
# https://gitlab.ow2.org/lemonldap-ng/lemonldap-ng/-/blob/dea7b235b10f6ae73b827419720f8faaa13d8005/debian/rules#L67-87
/var/cache/lemonldap-ng:
  file.directory:
  - user: www-data
  - group: www-data
  - dir_mode: 0750
  - require:
    - apache_httpd_pkgs

{{ accounts.llng_config_dir }}/db-csv exists:
  file.directory:
  - name: {{ accounts.llng_config_dir }}/db-csv
  - group: {{ apache_httpd.group }}
  - dir_mode: 0750
  - require:
    - accounts_pkgs
{{ accounts.llng_config_dir }}/db-csv is clean:
  file.directory:
  - name: {{ accounts.llng_config_dir }}/db-csv
  - clean: true
  - require:
    - {{ accounts.llng_config_dir }}/db-csv exists

{{ accounts.llng_config_dir }}/db-csv/user.csv:
  file.managed:
  - contents: |
      {{ csv_line('uid', 'mail', 'cn') }}
      {%- for username, user in pillar.accounts.users.items() %}
      {{ csv_line(username, user.email, user.name) }}
      {%- endfor %}
  - group: {{ apache_httpd.group }}
  - mode: 0640
  - require:
    - {{ accounts.llng_config_dir }}/db-csv exists
  - require_in:
    - {{ accounts.llng_config_dir }}/db-csv is clean

{{ accounts.llng_var_lib_dir }}/oidcsessions:
  file.directory:
  - user: {{ apache_httpd.user }}
  - group: {{ apache_httpd.group }}
  - dir_mode: 0770
  - require:
    - accounts_pkgs
{{ accounts.llng_var_lib_dir }}/oidcsessions/lock:
  file.directory:
  - user: {{ apache_httpd.user }}
  - group: {{ apache_httpd.group }}
  - dir_mode: 0770
  - require:
    - {{ accounts.llng_var_lib_dir }}/oidcsessions

{{ accounts.llng_config_dir }}/oauth2-client-secrets:
  file.directory:
  - dir_mode: 0700
  - require:
    - accounts_pkgs

{% for rp_name in pillar.accounts.oidc.rps %}
{{ accounts.llng_config_dir }}/oauth2-client-secrets/{{ rp_name }}:
  file.managed:
  - mode: 0600
  - replace: false
  - contents: {{ crypto.generate_password() | tojson }}
  - require:
    - {{ accounts.llng_config_dir }}/oauth2-client-secrets
{{ accounts.llng_config_dir }}/oauth2-client-secrets/{{ rp_name }} should be rotated:
  file.accumulated:
  - name: OAuth2 client secrets
  - filename: {{ common.local_sbin }}/monitor-secret-age
  - text: {{ accounts.llng_config_dir }}/oauth2-client-secrets/{{ rp_name }}
  - require:
    - {{ accounts.llng_config_dir }}/oauth2-client-secrets/{{ rp_name }}
  - require_in:
    - file: {{ common.local_sbin }}/monitor-secret-age
{% endfor %}

{{ accounts.llng_config_dir }}/lemonldap-ng.ini.orig:
  file.copy:
  - source: {{ accounts.llng_config_dir }}/lemonldap-ng.ini
  - require:
    - accounts_pkgs
  - creates:
    - {{ accounts.llng_config_dir }}/lemonldap-ng.ini.orig
{{ accounts.llng_config_dir }}/lemonldap-ng.ini.static:
  file.managed:
  - source: salt://accounts/lemonldap-ng.ini.jinja
  - user: root
  - group: {{ apache_httpd.group }}
  - mode: 0640
  - template: jinja
  - require:
    - {{ accounts.llng_config_dir }}/lemonldap-ng.ini.orig
    - /var/cache/lemonldap-ng
    - /etc/pam.d/lemonldap-ng
    - {{ accounts.llng_config_dir }}/db-csv is clean
    - {{ accounts.llng_var_lib_dir }}/oidcsessions
    - {{ accounts.llng_var_lib_dir }}/oidcsessions/lock
    {% for rp_name in pillar.accounts.oidc.rps %}
    - {{ accounts.llng_config_dir }}/oauth2-client-secrets/{{ rp_name }}
    {% endfor %}

{{ common.local_lib }}/generate-lemonldap-ng-ini:
  file.managed:
  - source: salt://accounts/generate_lemonldap_ng_ini.py
  - mode: 755
{{ accounts.llng_config_dir }}/lemonldap-ng.ini:
  cmd.run:
  - name: >-
      {{ common.local_lib }}/generate-lemonldap-ng-ini
      --input={{ accounts.llng_config_dir }}/lemonldap-ng.ini.static
      --output={{ accounts.llng_config_dir }}/lemonldap-ng.ini
  - onchanges:
    - {{ common.local_lib }}/generate-lemonldap-ng-ini
    - {{ accounts.llng_config_dir }}/lemonldap-ng.ini.static
  - watch_in:
    - apache_httpd_running
  cron.present:
  - name: >-
      {{ common.local_lib }}/generate-lemonldap-ng-ini
      --input={{ accounts.llng_config_dir }}/lemonldap-ng.ini.static
      --output={{ accounts.llng_config_dir }}/lemonldap-ng.ini
      &&
      systemctl reload-or-restart {{ apache_httpd.service }}
  - identifier: 0cb5cec2-5128-4694-a765-e78017aac9c8
  - minute: random
  - hour: random
  - dayweek: random
  - require:
    - cmd: {{ accounts.llng_config_dir }}/lemonldap-ng.ini

{{ apache_httpd.config_dir }}/sites-enabled/{{ pillar.accounts.name }}.conf:
  file.managed:
  - source: salt://accounts/portal.conf.jinja
  - template: jinja
  - require:
    - {{ apache_httpd.config_dir }}/sites-enabled exists
    - accounts_pkgs
    - {{ acme.certbot_config_dir }}/live/{{ pillar.accounts.name }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ pillar.accounts.name }}/privkey.pem
    - {{ accounts.llng_config_dir }}/lemonldap-ng.ini
  - require_in:
    - {{ apache_httpd.config_dir }}/sites-enabled is clean
  - watch_in:
    - apache_httpd_running
