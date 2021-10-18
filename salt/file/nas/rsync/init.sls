# Copyright 2021 David Mandelberg
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


{% from 'acme/map.jinja' import acme %}
{% from 'nas/map.jinja' import nas %}
{% from 'nas/rsync/map.jinja' import nas_rsync %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'stunnel/map.jinja' import stunnel %}


include:
- acme
- nas
- network.firewall
- stunnel


nas_rsync_pkgs:
  pkg.installed:
  - pkgs: {{ nas_rsync.pkgs | tojson }}


{{ nas_rsync.config_file }}:
  file.managed:
  - contents: |
      daemon uid = nas
      daemon gid = nas
      use chroot = false
      read only = true
      ignore nonreadable = true
      {% for share_name, share in pillar.nas.shares.items() %}
      [{{ share_name }}]
      path = {{ share.volume.replace('%', '%%') }}
      {% endfor %}
  - require: {{ (['nas_user'] + nas.share_requisites) | tojson }}

rsync_enabled:
  service.enabled:
  - name: {{ nas_rsync.service }}

rsync_running:
  service.running:
  - name: {{ nas_rsync.service }}
  - watch:
    - {{ nas_rsync.config_file }}

{{ stunnel.instance(
    instance_name='rsync',
    setuid='nas',
    setgid='nas',
    client=False,
    level='general',
    accept=':::874',
    key=(
        acme.certbot_config_dir + '/live/' + pillar.nas.hostname +
        '/privkey.pem'),
    cert=(
        acme.certbot_config_dir + '/live/' + pillar.nas.hostname +
        '/fullchain.pem'),
    connect='localhost:873',
    require=(
        'nas_user',
        'rsync_enabled',
        'rsync_running',
    ),
) }}


{{ acme.certbot_config_dir }}/renewal-hooks/post/50-nas-rsync:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash
      exec systemctl reload-or-restart {{ stunnel.service_instance('rsync') }}
  - require:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post exists
  - require_in:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post is clean


{{ nftables.config_dir }}/50-nas-rsync.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport { 873, 874 } accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
