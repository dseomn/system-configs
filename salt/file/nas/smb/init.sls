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


{% from 'nas/smb/map.jinja' import nas_smb %}
{% from 'network/firewall/map.jinja' import nftables %}


include:
- nas
- network.firewall


nas_smb_pkgs:
  pkg.installed:
  - pkgs: {{ nas_smb.pkgs | tojson }}


smbd_enabled:
  service.enabled:
  - name: {{ nas_smb.service }}
  - require:
    - nas_smb_pkgs
smbd_running:
  service.running:
  - name: {{ nas_smb.service }}
  - require:
    - nas_smb_pkgs

{{ nas_smb.config_dir }}/smb.conf:
  file.managed:
  - contents: |
      [global]
      server role = standalone
      map to guest = Bad User
      read only = yes
      guest ok = yes
      {% for share_name, share in pillar.nas.shares.items() %}
      [{{ share_name }}]
      path = {{ share.volume }}
      {% endfor %}
  - require:
    - nas_smb_pkgs
    - nas_share_requisites
  - watch_in:
    - smbd_running


{{ nftables.config_dir }}/50-nas-smb.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport 445 accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
