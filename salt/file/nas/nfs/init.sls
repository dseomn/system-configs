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


{% from 'nas/nfs/map.jinja' import nas_nfs %}
{% from 'network/firewall/map.jinja' import nftables %}


include:
- nas
- network.firewall


nas_nfs_pkgs:
  pkg.installed:
  - pkgs: {{ nas_nfs.pkgs | tojson }}


{{ nas_nfs.exports_file }}:
  file.blockreplace:
  - marker_start: '# START: salt nas.nfs :#'
  - marker_end: '# END: salt nas.nfs :#'
  - content: |
      {%- for share in pillar.nas.shares.values() %}
      "{{ share.volume }}" *(insecure,ro,mountpoint,all_squash)
      {%- endfor %}
  - append_if_not_found: true
  - require:
    - nas_nfs_pkgs
    - nas_share_requisites

nfs_enabled:
  service.enabled:
  - name: {{ nas_nfs.service }}
nfs_running:
  service.running:
  - name: {{ nas_nfs.service }}
  - watch:
    - {{ nas_nfs.exports_file }}

{{ nas_nfs.config_file }}:
  file.managed:
  - contents: |
      [mountd]
      manage-gids = true
      port = 32767
      [statd]
      port = 32765
      outgoing-port = 32766
      [lockd]
      port = 32768
  - require:
    - nas_nfs_pkgs
  - watch_in:
    - nfs_running


{{ nftables.config_dir }}/50-nas-nfs.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport { 111, 2049, 32765-32768 } accept
      add rule inet filter input udp dport { 111, 2049, 32765-32768 } accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
