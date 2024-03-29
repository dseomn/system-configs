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


{% from 'network/home_router/map.jinja' import home_router %}
{% from 'network/firewall/map.jinja' import nftables %}


include:
- network.firewall
- network.firewall.filter_postrouting
- network.firewall.nat_dstnat
- network.home_router.dns


net.ipv4.ip_forward:
  sysctl.present:
  - value: 1

net.ipv6.conf.all.forwarding:
  sysctl.present:
  - value: 1


dnsmasq_pkgs:
  pkg.installed:
  - pkgs: {{ home_router.dnsmasq_pkgs | tojson }}

{{ home_router.dnsmasq_conf }}:
  file.managed:
  - source: salt://network/home_router/dnsmasq.conf.jinja
  - template: jinja
  - require:
    - sls: network.home_router.dns

dnsmasq_enabled:
  service.enabled:
  - name: {{ home_router.dnsmasq_service }}

dnsmasq_running:
  service.running:
  - name: {{ home_router.dnsmasq_service }}
  - watch:
    - file: {{ home_router.dnsmasq_conf }}


{{ nftables.config_dir }}/50-home-router.conf:
  file.managed:
  - source: salt://network/home_router/nftables.conf.jinja
  - template: jinja
  - require:
    - sls: network.firewall.filter_postrouting
    - sls: network.firewall.nat_dstnat
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes

{{ home_router.update_nftables_bin }}:
  file.managed:
  - mode: 0700
  - source: salt://network/home_router/update-nftables.py
  - template: jinja
  cron.present:
  - identifier: 0df9d954-ff17-4317-81f1-ce733c31ef04
