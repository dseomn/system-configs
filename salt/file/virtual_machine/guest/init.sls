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


{% set guest = pillar.virtual_machine.guest %}


{% set mountpoint_states = [] %}
{% for data in guest.storage.get('data', []) %}
{% set mountpoint_state = 'mountpoint_' + data.uuid %}
{% do mountpoint_states.append(mountpoint_state) %}
{{ mountpoint_state }}:
  file.directory:
  - name: {{ data.mount }}
  - makedirs: true
{% endfor %}

virtual_machine_guest_volumes:
  file.blockreplace:
  - name: /etc/fstab
  - marker_start: '# START: salt virtual_machine.guest'
  - marker_end: '# END: salt virtual_machine.guest'
  - content: |
      {% for swap in guest.storage.get('swap', []) -%}
      UUID={{ swap.uuid }} none swap defaults 0 0
      {% endfor -%}
      {% for data in guest.storage.get('data', []) -%}
      UUID={{ data.uuid }} {{ data.mount }} ext4 defaults,x-systemd.growfs 0 2
      {% endfor %}
  - append_if_not_found: true
  - require: {{ mountpoint_states | json }}
  cmd.run:
  - name: >-
      swapon --verbose --all 2>&1 &&
      mount --verbose --all
  - onchanges:
    - file: virtual_machine_guest_volumes

{% for data in guest.storage.get('data', []) %}
{{ data.mount }}/.volume:
  file.directory:
  - mode: 700
  - require:
    - virtual_machine_guest_volumes

# Make it possible to map user/group IDs to names in backed up copies of the
# volume.
{{ data.mount }}/.volume/passwd:
  file.copy:
  - source: /etc/passwd
  - force: true
  - preserve: true
  # TODO(https://github.com/saltstack/salt/issues/55504): Remove the `unless`
  # requisite.
  - unless:
    - cmp {{ data.mount }}/.volume/passwd /etc/passwd
  - require:
    -  {{ data.mount }}/.volume
{% endfor %}
