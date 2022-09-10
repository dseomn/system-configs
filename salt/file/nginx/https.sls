# Copyright 2022 Google LLC
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


{% from 'crypto/map.jinja' import crypto %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'nginx/map.jinja' import nginx %}


include:
- network.firewall
- nginx
- nginx.http


{{ nginx.config_dir }}/local-http.d/10-https.conf:
  file.managed:
  - contents: |
      ssl_ciphers {{ crypto.openssl.ciphers_to_string(
          crypto.openssl.general_ciphers) }};
      ssl_protocols {{ ' '.join(crypto.openssl.general_protocols_enabled) }};
      ssl_session_tickets off;
      ssl_stapling on;
  - require:
    - {{ nginx.config_dir }}/local-http.d exists
  - require_in:
    - {{ nginx.config_dir }}/local-http.d is clean
  - watch_in:
    - nginx_running


{{ nftables.config_dir }}/50-nginx-https.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport 443 accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
