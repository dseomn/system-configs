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
{% from 'common/map.jinja' import common %}


include:
- backup
- ssh.server


{{ common.local_lib }}/backup/dump:
  file.directory:
  - require:
    - {{ common.local_lib }}/backup


{{ common.local_lib }}/backup/dump/sources exists:
  file.directory:
  - name: {{ common.local_lib }}/backup/dump/sources
  - require:
    - {{ common.local_lib }}/backup/dump
{{ common.local_lib }}/backup/dump/sources is clean:
  file.directory:
  - name: {{ common.local_lib }}/backup/dump/sources
  - require:
    - {{ common.local_lib }}/backup/dump/sources exists


{{ common.local_sbin}}/backup-dump:
  file.managed:
  - source: salt://backup/dump/main.py.jinja
  - mode: 0755
  - template: jinja


backup.dump authorized_keys:
  file.accumulated:
  - filename: /root/.ssh/authorized_keys
  - text: >-
      restrict,command="{{ common.local_sbin}}/backup-dump"
      {{ pillar.backup.source_hosts[
          pillar.backup.dump_hosts[grains.id].source].ssh_client_public_key }}
      {{ pillar.backup.dump_hosts[grains.id].source }}
  - require:
    - {{ common.local_sbin}}/backup-dump
  - require_in:
    - file: /root/.ssh/authorized_keys
