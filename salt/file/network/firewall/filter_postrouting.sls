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


{% from 'network/firewall/map.jinja' import nftables %}


include:
- network.firewall


{{ nftables.config_dir }}/10-filter-postrouting.conf:
  file.managed:
  - source: salt://network/firewall/filter_postrouting.nftables.conf.jinja
  - template: jinja
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
