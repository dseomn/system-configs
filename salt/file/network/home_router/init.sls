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
- network.home_router.dns


net.ipv4.ip_forward:
  sysctl.present:
  - value: 1

net.ipv6.conf.all.forwarding:
  sysctl.present:
  - value: 1


dnsmasq_pkg:
  pkg.installed:
  - name: {{ home_router.dnsmasq_pkg }}

{{ home_router.dnsmasq_conf }}:
  file.managed:
  - source: salt://network/home_router/dnsmasq.conf.jinja
  - template: jinja
  - require:
    - sls: network.home_router.dns

{{ nftables.config_dir }}/dnsmasq.conf:
  file.managed:
  - source: salt://network/home_router/dnsmasq.nftables.conf.jinja
  - template: jinja

dnsmasq_service:
  service.running:
  - name: {{ home_router.dnsmasq_service }}
  - enable: true
  - watch:
    - file: {{ home_router.dnsmasq_conf }}
