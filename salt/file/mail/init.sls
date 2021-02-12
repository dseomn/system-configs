# Copyright 2019 Google LLC
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


{% set postfix = salt.grains.filter_by({
    'Debian': {
        'pkg': 'postfix',
        'service': 'postfix',
        'config_directory': '/etc/postfix',
    },
}) %}


include:
- pki.public

postfix:
  pkg.installed:
  - name: {{ postfix.pkg }}
  service.running:
  - name: {{ postfix.service }}
  - enable: True
  - watch:
    - file: postfix_main

aliases:
  file.managed:
  - name: /etc/aliases
  - source: salt://mail/aliases.jinja2
  - template: jinja
  cmd.run:
  - name: newaliases
  - onchanges:
    - file: aliases

postfix_main:
  file.managed:
  - name: {{ postfix.config_directory }}/main.cf
  - source: salt://mail/postfix/main.cf.jinja2
  - template: jinja
  - require:
    - sls: pki.public
