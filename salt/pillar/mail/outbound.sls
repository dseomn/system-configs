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

{% set include_passwords = True %}
{% set include_sieve = False %}
{% set mailbox_accounts_only = False %}
{% from 'mail/map.jinja' import mail with context %}

{% import_yaml 'mail/outbound.yaml.jinja' as outbound %}

mail:
  accounts: {{ mail.accounts | tojson }}
  authoritative_domains: {{ mail.authoritative_domains | tojson }}
  authoritative_non_sub_domains: {{ mail.authoritative_non_sub_domains | tojson }}
  logins_by_account: {{ mail.logins_by_account | tojson }}
  outbound: {{ outbound | tojson }}
  recipient_addresses: {{ mail.recipient_addresses | tojson }}
  recipient_domains: {{ mail.recipient_domains | tojson }}
  system: {{ mail.system | tojson }}
