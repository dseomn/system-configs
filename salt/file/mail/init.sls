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


{% from 'mail/map.jinja' import mail %}


include:
- crypto


mail_pkgs:
  pkg.installed:
  - pkgs: {{ mail.pkgs | json }}


postfix_enabled:
  service.enabled:
  - name: {{ mail.postfix_service }}
  - require:
    - mail_pkgs

postfix_running:
  service.running:
  - name: {{ mail.postfix_service }}
  - require:
    - mail_pkgs

/etc/aliases:
  file.managed:
  - source: salt://mail/aliases.jinja
  - template: jinja
{{ mail.postalias('/etc/aliases') }}

{{ mail.postfix_config_dir() }}/main.cf:
  file.managed:
  - source: salt://mail/main.cf.jinja
  - template: jinja
  - require:
    - mail_pkgs
    - /etc/aliases
    - crypto_pkgs
  - watch_in:
    - postfix_running


echo mail delivery test:
  cron.present:
  - identifier: 492b832c-fd8f-446b-821f-7bfd7ee44b9b
  # Spread out the emails throughout the day, to make it very likely that emails
  # from different hosts will arrive in the same order each time, making it
  # easier to see changes from the previous time.
  - minute: random
  - hour: random
  # But test all hosts on the same day, to make it easy to check all hosts at
  # once, the day after the test.
  - daymonth: 1
