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


{% from 'backup/map.jinja' import backup %}


{{ backup.config_dir }}:
  file.directory: []

create_config_sources_dir:
  file.directory:
  - name: {{ backup.config_dir }}/sources.d
  - require:
    - {{ backup.config_dir }}
manage_config_sources_dir:
  file.directory:
  - name: {{ backup.config_dir }}/sources.d
  - clean: true
  - require:
    - create_config_sources_dir


{{ backup.backup_exec }}:
  file.managed:
  - mode: 0755
  - source: salt://backup/backup_exec.py.jinja
  - template: jinja
