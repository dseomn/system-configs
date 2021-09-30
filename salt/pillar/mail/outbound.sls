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
{% from 'mail/map.jinja' import mail with context %}

{% import_yaml 'mail/outbound.yaml.jinja' as outbound %}

mail:
  accounts: {{ mail.accounts | json }}
  authoritative_domains: {{ mail.authoritative_domains | json }}
  authoritative_non_sub_domains: {{ mail.authoritative_non_sub_domains | json }}
  logins_by_account: {{ mail.logins_by_account | json }}
  outbound: {{ outbound | json }}
  recipient_addresses: {{ mail.recipient_addresses | json }}
  recipient_domains: {{ mail.recipient_domains | json }}
  system: {{ mail.system | json }}
