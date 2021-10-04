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

{% set mailbox_accounts_only = True %}
{% set include_passwords = True %}
{% from 'mail/map.jinja' import mail with context %}

{% import_yaml 'mail/storage.yaml.jinja' as storage %}

{% for account_name, account in mail.accounts.items() %}
  {% import_text 'mail/sieve/' + account_name + '.sieve' as sieve_script %}
  {% do account.update({'sieve': sieve_script}) %}
{% endfor %}

mail:
  accounts: {{ mail.accounts | tojson }}
  logins_by_account: {{ mail.logins_by_account | tojson }}
  mailbox_domains: {{ mail.mailbox_domains | tojson }}
  storage: {{ storage | tojson }}
