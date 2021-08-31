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


{% from 'vcs/map.jinja' import vcs %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- virtual_machine.guest


vcs_pkgs:
  pkg.installed:
  - pkgs: {{ vcs.pkgs }}


{% for user in pillar.users.users %}

/srv/vcs/{{ user }}:
  file.directory:
  - user: {{ user }}
  - group: {{ user }}
  - mode: 0700
  - require:
    - /srv/vcs
    - virtual_machine_guest_volumes

~{{ user }}/.bashrc:
  file.blockreplace:
  - marker_start: '# START: salt vcs'
  - marker_end: '# END: salt vcs'
  - content: |
      cd /srv/vcs
  - prepend_if_not_found: true

{% endfor %}
