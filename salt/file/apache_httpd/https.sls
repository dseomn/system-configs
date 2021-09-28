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


{% from 'apache_httpd/map.jinja' import apache_httpd %}
{% from 'crypto/map.jinja' import crypto %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'port_mux/map.jinja' import port_mux %}


include:
- apache_httpd
- apache_httpd.socache_shmcb
- network.firewall


{{ apache_httpd.enable_mod('ssl.conf') }}
{{ apache_httpd.enable_mod('ssl.load') }}

{{ apache_httpd.config_dir }}/conf-enabled/https.conf:
  file.managed:
  - contents: |
      Listen 443 https
      SSLCipherSuite {{ crypto.openssl.ciphers_to_string(
          crypto.openssl.general_ciphers) }}
      SSLProtocol all {{ crypto.openssl.protocols_disabled_to_string(
          crypto.openssl.general_protocols_disabled) }}
      SSLSessionTickets off
      SSLStaplingCache shmcb:${APACHE_RUN_DIR}/ssl_stapling_cache
      SSLStrictSNIVHostCheck on
      SSLUseStapling on
  - require:
    - {{ apache_httpd.config_dir }}/conf-enabled exists
  - require_in:
    - {{ apache_httpd.config_dir }}/conf-enabled is clean
  - watch_in:
    - apache_httpd_running


{{ nftables.config_dir }}/50-apache-httpd-https.conf:
  file.managed:
  - contents: |
      {{ port_mux.nftables_from_upstream_or_all(
          prefix='add rule inet filter input',
          suffix='tcp dport 443 accept'
      ) | indent(6) }}
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
