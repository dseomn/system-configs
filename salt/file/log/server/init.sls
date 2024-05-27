# Copyright 2024 Google LLC
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


{% from 'common/map.jinja' import common %}
{% from 'crypto/x509/map.jinja' import x509 %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'virtual_machine/guest/map.jinja' import require_running_on_vm_guest %}


{{ require_running_on_vm_guest() }}


include:
- crypto.x509
- log.syslog_ng
- network.firewall
- virtual_machine.guest


log_server_pkgs:
  pkg.installed:
  - pkgs:
    - jq  # To read json-formatted logs.


{{ x509.boilerplate_certificate(
    name=pillar.log.common.server.name,
    warning_on_change='Update salt/pillar/log/common.sls',
    group='syslog-ng',
    keep_ca_cert=true,
) }}


/srv/logs:
  test.nop:
  - require:
    - /srv/logs is mounted
    - /srv/logs is backed up

/srv/logs/current:
  file.directory:
  - user: syslog-ng
  - group: adm
  - mode: 0750
  - require:
    - /srv/logs
    - syslog-ng user and group


/etc/syslog-ng/conf.d/server-ca-certs.pem:
  file.managed:
  - user: root
  - group: syslog-ng
  - mode: 0640
  - contents: |
      {%- for peer_name, peer in pillar.log.server.clients | dictsort %}
      {{ peer.ca_certificate | indent(6) }}
      {%- endfor %}
  - require:
    - /etc/syslog-ng/conf.d exists
  - require_in:
    - /etc/syslog-ng/conf.d is clean
  - watch_in:
    - syslog_ng_running

/etc/syslog-ng/conf.d/server.conf:
  file.managed:
  - user: root
  - group: syslog-ng
  - mode: 0640
  - source: salt://log/server/syslog-ng.conf.jinja
  - template: jinja
  - require:
    - /etc/syslog-ng/conf.d exists
    - {{ common.local_etc }}/x509/{{ pillar.log.common.server.name }}/cert.pem
    - {{ common.local_etc }}/x509/{{ pillar.log.common.server.name }}/privkey.pem
    - /etc/syslog-ng/conf.d/server-ca-certs.pem
    - /srv/logs/current
  - require_in:
    - /etc/syslog-ng/conf.d is clean
  - watch_in:
    - syslog_ng_running


{{ nftables.config_dir }}/50-log-server.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport 6514 accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
