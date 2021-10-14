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


{% from 'disk_usage/map.jinja' import disk_usage %}


{{ disk_usage.bin }}:
  file.managed:
  - mode: 0755
  - source: salt://disk_usage/disk_usage_at_least.py

{{ disk_usage.bin }} --lvm-pool-threshold=0 --fs-threshold=5:
  cron.present:
  - identifier: facf3bb7-d24d-4f45-aaea-7886457b160b
  - minute: random
  - hour: random
  - daymonth: random
  - month: random
{{ disk_usage.bin }} --lvm-pool-threshold=70 --fs-threshold=80:
  cron.present:
  - identifier: 019261b3-a7df-49aa-a68e-3838302df043
  - minute: random
  - hour: random
  - dayweek: random
{{ disk_usage.bin }} --lvm-pool-threshold=80 --fs-threshold=90:
  cron.present:
  - identifier: 5ecec10e-0d38-4b90-82cf-46be30568fa0
  - minute: random
  - hour: random
