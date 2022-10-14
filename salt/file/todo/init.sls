# Copyright 2022 Google LLC
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
{% from 'todo/map.jinja' import todo %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- common
- virtual_machine.guest


todo_pkgs:
  pkg.installed:
  - pkgs: {{ todo.pkgs }}


{{ common.system_user_and_group('todo') }}


{{ common.local_bin }}/todo:
  file.managed:
  - source: salt://todo/todo.py
  - mode: 0755
  - require:
    - todo_pkgs

{{ common.local_etc }}/todo.json:
  file.managed:
  - group: todo
  - mode: 640
  - contents: {{ pillar.todo | tojson(indent=2) | tojson }}
  - require:
    - todo user and group

/var/local/todo/state:
  file.directory:
  - user: todo
  - group: todo
  - mode: 700
  - require:
    - /var/local/todo is mounted
    - /var/local/todo is backed up

todo_cron:
  cron.present:
  - name: >-
      {{ common.local_bin }}/todo
      --config={{ common.local_etc }}/todo.json
      --state=/var/local/todo/state/state.json
  - user: todo
  - identifier: c0a8b1c0-2457-4eb6-bba3-3a2851a9e170
  - minute: random
  - require:
    - {{ common.local_bin }}/todo
    - {{ common.local_etc }}/todo.json
    - /var/local/todo/state
    - todo user and group
