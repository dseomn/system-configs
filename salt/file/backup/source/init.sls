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
{% from 'backup/source/map.jinja' import backup_source %}


include:
- backup


{{ backup.config_dir }}/source:
  file.directory:
  - require:
    - {{ backup.config_dir }}


create_backup_source_sources_d:
  file.directory:
  - name: {{ backup.config_dir }}/source/sources.d
  - require:
    - {{ backup.config_dir }}/source
manage_backup_source_sources_d:
  file.directory:
  - name: {{ backup.config_dir }}/source/sources.d
  - clean: true
  - require:
    - create_backup_source_sources_d


{{ backup_source.backup_exec }}:
  file.managed:
  - mode: 0755
  - source: salt://backup/source/backup_exec.py.jinja
  - template: jinja
