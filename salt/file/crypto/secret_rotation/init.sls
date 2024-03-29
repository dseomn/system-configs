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


{{ common.local_sbin }}/monitor-secret-age:
  file.managed:
  - source: salt://crypto/secret_rotation/monitor.sh.jinja
  - mode: 0755
  - template: jinja
  cron.present:
  - identifier: b5388f15-3391-47f9-bdc5-509e4bfda051
  - minute: random
  - hour: random
  - daymonth: random
  - require:
    - file: {{ common.local_sbin }}/monitor-secret-age
