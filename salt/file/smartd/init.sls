# Copyright 2019 Google LLC
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


{% set smartd = salt['grains.filter_by']({
    'Debian': {
        'pkg': 'smartmontools',
        'service': 'smartd',
    },
}) %}


smartd:
  pkg.installed:
  - name: {{ smartd.pkg }}
  service.running:
  - name: {{ smartd.service }}
  - enable: True
