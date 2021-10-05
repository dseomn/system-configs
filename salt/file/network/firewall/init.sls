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


{% from 'network/firewall/map.jinja' import nftables %}


warn about firewall changes:
  test.configurable_test_state:
  - warnings: >-
      Run `sudo systemctl restart {{ nftables.service }}` to pick up firewall
      changes, then test ssh with `ssh -S none {{ grains.id }}`

nftables.conf:
  file.managed:
  - name: {{ nftables.config_file }}
  - mode: 0755
  - source: salt://network/firewall/nftables.conf.jinja
  - template: jinja
  - onchanges_in:
    - warn about firewall changes

create_nftables_config_dir:
  file.directory:
  - name: {{ nftables.config_dir }}
manage_nftables_config_dir:
  file.directory:
  - name: {{ nftables.config_dir }}
  - clean: true
  - require:
    - create_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes

{% set custom_rules = salt['pillar.get'](
    'network:hosts:{}:firewall:custom_nftables'.format(grains.id), None) %}
{% if custom_rules is not none %}
{{ nftables.config_dir }}/90-local.conf:
  file.managed:
  - contents: {{ custom_rules | tojson }}
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
{% endif %}
