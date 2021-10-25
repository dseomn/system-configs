# Copyright 2020 Google LLC
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


{% set rygel = salt.grains.filter_by({
    'Debian': {
        'pkgs': ['rygel', 'rygel-playbin', 'gstreamer1.0-alsa'],
        'user_home': '/var/lib/rygel',
        'user_groups': ['audio'],
        'service_file': '/usr/share/doc/rygel/examples/service/systemd/rygel.service',
        'systemd_directory': '/etc/systemd/system',
        'service': 'rygel',
        'config_file': '/etc/rygel.conf',
        'port': 60240,
    },
}) %}

{% from 'common/map.jinja' import common %}
{% from 'network/firewall/map.jinja' import nftables %}


include:
- network.firewall


rygel_pkgs:
  pkg.installed:
  - pkgs: {{ rygel.pkgs | tojson }}

{{ common.system_user_and_group(
    'rygel',
    groups=rygel.user_groups,
    home=rygel.user_home,
    createhome=True,
) }}

{{ rygel.systemd_directory }}/{{ rygel.service }}.service:
  file.symlink:
  - target: {{ rygel.service_file }}

rygel_enabled:
  service.enabled:
  - name: {{ rygel.service }}

rygel_running:
  service.running:
  - name: {{ rygel.service }}
  - watch:
    - file: rygel.conf

rygel.conf:
  file.managed:
  - name: {{ rygel.config_file }}
  - source: salt://dlna/renderer/rygel.conf.jinja
  - template: jinja
  - defaults:
      rygel: {{ rygel | tojson }}

rygel_port:
  file.managed:
  - name: {{ nftables.config_dir }}/50-rygel.conf
  - source: salt://dlna/renderer/nftables.conf.jinja
  - template: jinja
  - defaults:
      rygel: {{ rygel | tojson }}
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
