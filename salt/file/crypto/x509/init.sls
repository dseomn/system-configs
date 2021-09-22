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


{% from 'common/map.jinja' import common %}


include:
- crypto
- crypto.secret_rotation


{{ common.local_etc }}/x509:
  file.directory: []

{{ common.local_bin }}/boilerplate-certificate:
  file.managed:
  - source: salt://crypto/x509/boilerplate_certificate.py
  - mode: 0755
  - require:
    - crypto_pkgs

{{ common.local_sbin }}/monitor-x509-validity-period:
  file.managed:
  - source: salt://crypto/x509/monitor-validity-period.sh.jinja
  - mode: 0755
  - template: jinja
  cron.present:
  - identifier: fc2ccbee-9f46-4e95-a326-354d2ba84d4c
  - minute: random
  - hour: random
  - daymonth: random
  - require:
    - file: {{ common.local_sbin }}/monitor-x509-validity-period
