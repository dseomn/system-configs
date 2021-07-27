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


{% from 'network/home_router/dns/map.jinja' import dns %}


# Resolver for public names, where the authoritative servers care about the
# resolver's IP address.
unbound_pkg:
  pkg.installed:
  - name: {{ dns.unbound_pkg }}

unbound_conf:
  file.managed:
  - name: {{ dns.unbound_conf_dir }}/local.conf
  - source: salt://network/home_router/dns/unbound.local.conf.jinja
  - template: jinja

unbound_service:
  service.running:
  - name: {{ dns.unbound_service }}
  - enable: true
  - watch:
    - file: unbound_conf


# Main resolver for public names.
dnss_pkg:
  pkg.installed:
  - name: {{ dns.dnss_pkg }}

dnss_socket_unit:
  file.managed:
  - name: {{ dns.dnss_socket_unit }}.d/50-local.conf
  - source: salt://network/home_router/dns/dnss.local.socket.conf.jinja
  - makedirs: true
  - template: jinja

dnss_service_unit:
  file.managed:
  - name: {{ dns.dnss_service_unit }}.d/50-local.conf
  - source: salt://network/home_router/dns/dnss.local.service.conf.jinja
  - makedirs: true
  - template: jinja
  - require:
    - service: unbound_service

dnss_unit_reload:
  cmd.run:
  - name: systemctl daemon-reload
  - onchanges_any:
    - file: dnss_socket_unit
    - file: dnss_service_unit

dnss_socket:
  service.running:
  - name: {{ dns.dnss_service }}.socket
  - watch:
    - cmd: dnss_unit_reload

dnss_service:
  service.running:
  - name: {{ dns.dnss_service }}.service
  - enable: true
  - watch:
    - service: dnss_socket
