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
      {{ csv_line('uid', 'mail') }}
      {%- for username, user in pillar.accounts.users.items() %}
      {{ csv_line(username, user.email) }}
      {%- endfor %}
  - group: {{ apache_httpd.group }}
  - mode: 0640
  - require:
    - {{ accounts.llng_config_dir }}/db-csv exists
  - require_in:
    - {{ accounts.llng_config_dir }}/db-csv is clean

{{ accounts.llng_config_dir }}/lemonldap-ng.ini.orig:
  file.copy:
  - source: {{ accounts.llng_config_dir }}/lemonldap-ng.ini
  - require:
    - accounts_pkgs
{{ accounts.llng_config_dir }}/lemonldap-ng.ini:
  file.managed:
  - source: salt://accounts/lemonldap-ng.ini.jinja
  - template: jinja
  - require:
    - {{ accounts.llng_config_dir }}/lemonldap-ng.ini.orig
    - /var/cache/lemonldap-ng
    - /etc/pam.d/lemonldap-ng
    - {{ accounts.llng_config_dir }}/db-csv is clean
  - watch_in:
    - apache_httpd_running
