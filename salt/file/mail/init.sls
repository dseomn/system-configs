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


{% from 'common/map.jinja' import common %}
{% from 'crypto/map.jinja' import crypto %}
{% from 'mail/map.jinja' import mail %}


include:
- crypto
- crypto.secret_rotation


mail_pkgs:
  pkg.installed:
  - pkgs: {{ mail.pkgs | tojson }}


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

{% set relay_password_file =
    mail.postfix_config_dir() + '/smtp_sasl_password_' +
    pillar.mail.common.outbound.name %}
{{ relay_password_file }}:
  file.managed:
  - mode: 0600
  - replace: false
  - contents: {{ crypto.generate_password() | tojson }}
  - require:
    - mail_pkgs
show dovecot_password for relay:
  cmd.run:
  - name: >-
      printf '%s' "$SCRIPT" | python3 - {{ relay_password_file }}
  - env:
    - SCRIPT: |
        import crypt
        import sys
        with open(sys.argv[1], mode='rt') as password_file:
            password = password_file.read().rstrip('\n')
        crypted = crypt.crypt(password, crypt.METHOD_SHA512)
        print('{SHA512-CRYPT}' + crypted)
  - onchanges:
    - {{ relay_password_file }}
  test.configurable_test_state:
  - warnings: >-
      Update salt/pillar/mail/accounts.yaml.jinja with new dovecot_password.
  - onchanges:
    - cmd: show dovecot_password for relay
{{ relay_password_file }} should be rotated:
  file.accumulated:
  - name: local mail relay passwords
  - filename: {{ common.local_sbin }}/monitor-secret-age
  - text: {{ relay_password_file }}
  - require:
    - {{ relay_password_file }}
  - require_in:
    - file: {{ common.local_sbin }}/monitor-secret-age
{{ mail.postfix_config_dir() }}/smtp_sasl_password:
  file.managed:
  - source: salt://mail/smtp_sasl_password.jinja
  - mode: 0600
  - template: jinja
  - context:
      relay_password_file: {{ relay_password_file }}
  - require:
    - {{ relay_password_file }}
{{ mail.postmap('smtp_sasl_password') }}

{{ mail.postfix_config_dir() }}/main.cf:
  file.managed:
  - source: salt://mail/main.cf.jinja
  - template: jinja
  - require:
    - mail_pkgs
    - /etc/aliases
    - {{ mail.postfix_config_dir() }}/smtp_sasl_password
  - watch_in:
    - postfix_running


# Check if there's any queued mail in any postfix instance. The -j for json
# format is because json format has no output if the queue is empty, despite not
# being as human-readable. This might have some false alerts if it happens to
# run when a queue has barely-delayed emails. If that happens enough, it might
# be worth writing a script to filter out too-recent queue entries. The
# frequency of this cronjob is a balance between finding out sooner if there's
# an issue, and not filling up the queue if all mail is delayed for a while
# (including the mails about delayed mail).
postmulti -x postqueue -j:
  cron.present:
  - identifier: c512650f-a208-4abd-b48a-4e21eef53177
  - minute: random
  - hour: random


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
