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


{% set guest = pillar.virtual_machine.guest %}


{% set includes = [
    'common',
] %}


{% set mountpoints = [] %}
{% set mountpoint_states = [] %}

{% for data in guest.storage.get('data', []) %}
{% do mountpoints.append(data.mount) %}
{% do mountpoint_states.append(data.mount + ' exists') %}
{{ data.mount }} exists:
  file.directory:
  - name: {{ data.mount }}
  - makedirs: true

{% if data.get('backup', True) %}
{{ data.mount }} is backed up:
  test.nop: []
{% else %}
{{ data.mount }} is not backed up:
  test.nop: []
{% endif %}
{% endfor %}

{% for passthrough in guest.storage.get('passthrough', ()) %}
{% do mountpoints.append(passthrough.mount) %}
{% do mountpoint_states.append(passthrough.mount + ' exists') %}
{{ passthrough.mount }} exists:
  file.directory:
  - name: {{ passthrough.mount }}
  - makedirs: true

{{ passthrough.mount }} is not backed up:
  test.nop: []
{% endfor %}

# See cryptsetup.ephemeral_swap for where swap volumes are managed.
virtual_machine_guest_volumes:
  file.blockreplace:
  - name: /etc/fstab
  - marker_start: '# START: salt virtual_machine.guest :#'
  - marker_end: '# END: salt virtual_machine.guest :#'
  - content: |
      {% for data in guest.storage.get('data', []) -%}
      UUID={{ data.uuid }} {{ data.mount }} ext4 defaults,x-systemd.growfs 0 2
      {% endfor -%}
      {% for passthrough in guest.storage.get('passthrough', ()) -%}
      UUID={{ passthrough.uuid }} {{ passthrough.mount }} ext4 defaults 0 2
      {% endfor %}
  - append_if_not_found: true
  - require: {{ mountpoint_states | tojson }}
  cmd.run:
  - name: mount --verbose --all
  - onchanges:
    - file: virtual_machine_guest_volumes

{% for mountpoint in mountpoints %}
{{ mountpoint }} is mounted:
  test.fail_without_changes:
  - require:
    - virtual_machine_guest_volumes
  - unless:
    - fun: mount.is_mounted
      args:
      - {{ mountpoint }}

{{ mountpoint }}/.volume:
  file.directory:
  - mode: 700
  - require:
    - {{ mountpoint }} is mounted

# Make it possible to map user/group IDs to names in backed up copies of the
# volume.
{% for target, source in {
    'group': '/etc/group',
    'passwd': '/etc/passwd',
}.items() %}
{{ mountpoint }}/.volume/{{ target }}:
  file.copy:
  - source: {{ source }}
  - force: true
  - preserve: true
  # TODO(https://github.com/saltstack/salt/issues/55504): Remove the `unless`
  # requisite.
  - unless:
    - cmp {{ mountpoint }}/.volume/{{ target }} {{ source }}
  - require:
    - {{ mountpoint }}/.volume
    - users and groups are done
{% endfor %}
{% endfor %}


{% if 'backup_dump' in guest %}
{% do includes.append('backup.dump') %}

{% for dump in guest['backup_dump'] %}
{{ common.local_lib }}/backup/dump/sources/{{ dump.source }} is dumped:
  test.nop: []
{% endfor %}
{% endif %}


include: {{ includes | tojson }}
