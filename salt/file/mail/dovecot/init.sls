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


{% from 'mail/dovecot/map.jinja' import dovecot %}


dovecot_pkgs:
  pkg.installed:
  - pkgs: {{ dovecot.pkgs | json }}

dovecot_enabled:
  service.enabled:
  - name: {{ dovecot.service }}
  - require:
    - dovecot_pkgs

dovecot_running:
  service.running:
  - name: {{ dovecot.service }}
  - require:
    - dovecot_pkgs

{{ dovecot.config_dir }} exists:
  file.directory:
  - name: {{ dovecot.config_dir }}
  - require:
    - dovecot_pkgs
{{ dovecot.config_dir }} is clean:
  file.directory:
  - name: {{ dovecot.config_dir }}
  - clean: true
  - require:
    - {{ dovecot.config_dir }} exists
  - watch_in:
    - dovecot_running

{{ dovecot.config_dir }}/10-passwd:
  file.managed:
  - group: {{ dovecot.group }}
  - mode: 0640
  - contents: |
      {%- for account_name, logins in pillar.mail.logins_by_account.items() %}
      {%- for login_name, password in logins.items() %}
      {{ login_name }}:{{ password }}::::::user={{ account_name }}
      {%- endfor %}
      {%- endfor %}
  - require:
    - {{ dovecot.config_dir }} exists
  - require_in:
    - {{ dovecot.config_dir }} is clean
  - watch_in:
    - dovecot_running
{{ dovecot.config_dir }}/10-passwd.conf:
  file.managed:
  - contents: |
      auth_username_chars = {{
          '+-.'
          '0123456789'
          '@'
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
          'abcdefghijklmnopqrstuvwxyz'
      }}
      service auth-worker {
        # No need to be root to read the passwd file.
        user = $default_internal_user
      }
      passdb {
        driver = passwd-file
        args = {{ dovecot.config_dir }}/10-passwd
      }
      userdb {
        driver = passwd-file
        args = {{ dovecot.config_dir }}/10-passwd
      }
  - require:
    - {{ dovecot.config_dir }} exists
    - {{ dovecot.config_dir }}/10-passwd
  - require_in:
    - {{ dovecot.config_dir }} is clean
  - watch_in:
    - dovecot_running
