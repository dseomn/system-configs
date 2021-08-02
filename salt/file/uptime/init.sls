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


{% from 'uptime/map.jinja' import uptime %}


{{ uptime.bin }}:
  file.managed:
  - mode: 0755
  - source: salt://uptime/uptime_warning.py
  cron.present:
  - identifier: 4b981b96-b1a7-4595-b48b-c39e8f741196
  - minute: random
  - hour: random
  - dayweek: random
