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


include:
- crypto.x509
- log.syslog_ng


{{ x509.boilerplate_certificate(
    name=grains.id,
    dir_name=grains.id + '_log_client',
    warning_on_change='Update salt/pillar/log/server.sls',
    group='syslog-ng',
    keep_ca_cert=true,
) }}

/etc/syslog-ng/conf.d/client-ca-certs.pem:
  file.managed:
  - contents: {{ pillar.log.common.server.ca_certificate | tojson }}
  - require:
    - /etc/syslog-ng/conf.d exists
  - require_in:
    - /etc/syslog-ng/conf.d is clean
  - watch_in:
    - syslog_ng_running

/etc/syslog-ng/conf.d/client.conf:
  file.managed:
  - source: salt://log/client/syslog-ng.conf.jinja
  - template: jinja
  - require:
    - /etc/syslog-ng/conf.d exists
    - {{ common.local_etc }}/x509/{{ grains.id }}_log_client/cert.pem
    - {{ common.local_etc }}/x509/{{ grains.id }}_log_client/privkey.pem
    - /etc/syslog-ng/conf.d/client-ca-certs.pem
  - require_in:
    - /etc/syslog-ng/conf.d is clean
  - watch_in:
    - syslog_ng_running
