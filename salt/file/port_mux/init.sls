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
{% from 'nginx/map.jinja' import nginx %}


{% set proxy_by_server_name_by_tls_port = {} %}
{% for server_name, proxy_by_tls_port in pillar.port_mux.tls.items() %}
  {% for tls_port, proxy in proxy_by_tls_port.items() %}
    {% do proxy_by_server_name_by_tls_port.setdefault(tls_port, {}).update(
        {server_name: proxy}) %}
  {% endfor %}
{% endfor %}


include:
- network.firewall
- nginx
- nginx.stream


{{ nginx.config_dir }}/local-stream.d/50-port-mux.conf:
  file.managed:
  - contents: |
      {%- for tls_port, proxy_by_server_name
          in proxy_by_server_name_by_tls_port | dictsort %}
      map $ssl_preread_server_name $port_mux_tls_{{ tls_port }}_backend {
        hostnames;
        {%- for server_name, proxy in proxy_by_server_name | dictsort %}
        {{ server_name }} {{ proxy.backend }};
        {%- endfor %}
      }
      server {
        # This uses two `listen` statements instead of a single one with
        # ipv6only=off because of how addresses are sent to the backend. E.g.,
        # see https://bz.apache.org/bugzilla/show_bug.cgi?id=63349
        listen 0.0.0.0:{{ tls_port }};
        listen [::]:{{ tls_port }} ipv6only=on;
        ssl_preread on;
        proxy_protocol on;
        proxy_pass $port_mux_tls_{{ tls_port }}_backend;
      }
      {%- endfor %}
  - require:
    - {{ nginx.config_dir }}/local-stream.d exists
  - require_in:
    - {{ nginx.config_dir }}/local-stream.d is clean
  - watch_in:
    - nginx_running


{% set open_tcp_ports = ', '.join(
    proxy_by_server_name_by_tls_port | sort | map('string')) %}
{{ nftables.config_dir }}/50-port-mux.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport { {{ open_tcp_ports }} } accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
