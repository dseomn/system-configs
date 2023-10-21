# Copyright 2023 Google LLC
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


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- virtual_machine.guest


media_tracker_pkgs:
  pkg.installed:
  - pkgs:
    - git
    - protobuf-compiler
    - python3-absl
    - python3-dateutil
    - python3-filelock
    - python3-immutabledict
    - python3-jmespath
    - python3-jsonschema
    - python3-pip
    - python3-protobuf
    - python3-requests
    - python3-requests-cache
    - python3-setuptools
    - python3-setuptools-protobuf
    - python3-urllib3
    - python3-yaml


rock_paper_sand_src:
  git.latest:
  - name: https://github.com/dseomn/rock-paper-sand.git
  - rev: main
  - target: /usr/local/src/rock-paper-sand
  - branch: main
  - require:
    - media_tracker_pkgs

rock_paper_sand_installed:
  cmd.run:
  - name: >-
      pip
      install
      --break-system-packages
      --no-build-isolation
      --no-deps
      --no-index
      --upgrade
      /usr/local/src/rock-paper-sand
  - require:
    - media_tracker_pkgs
  - onchanges:
    - rock_paper_sand_src


{% for user, rock_paper_sand_config in pillar.media_tracker.users.items() %}

~{{ user }}/.config/rock-paper-sand/config.yaml:
  file.managed:
  - user: {{ user }}
  - group: {{ user }}
  - mode: 0600
  - makedirs: true
  - dir_mode: 0700
  - contents: {{ rock_paper_sand_config | tojson }}
  cmd.run:
  - name: rock-paper-sand config lint
  - runas: {{ user }}
  - onchanges:
    - rock_paper_sand_installed
    - file: ~{{ user }}/.config/rock-paper-sand/config.yaml

/var/local/media-tracker/{{ user }}:
  file.directory:
  - user: {{ user }}
  - group: {{ user }}
  - mode: 0700
  - require:
    - /var/local/media-tracker is mounted
    - /var/local/media-tracker is backed up
~{{ user }}/.local/share/rock-paper-sand:
  file.symlink:
  - target: /var/local/media-tracker/{{ user }}
  - makedirs: true
  - user: {{ user }}
  - group: {{ user }}
  - mode: 0700
  - require:
    - /var/local/media-tracker/{{ user }}

{% endfor %}

{% for user in salt.user.list_users() %}
{% set job_id = user + '/8ecfa7d5-6905-4b4d-9d18-9094f74f0963' %}
{% if user in pillar.media_tracker.users %}
{{ job_id | tojson }}:
  cron.present:
  - name: /usr/local/bin/rock-paper-sand reports notify
  - user: {{ user }}
  - identifier: {{ job_id | tojson }}
  - minute: random
  - require:
    - rock_paper_sand_installed
    - ~{{ user }}/.config/rock-paper-sand/config.yaml
    - ~{{ user }}/.local/share/rock-paper-sand
{% else %}
{{ job_id | tojson }}:
  cron.absent:
  - user: {{ user }}
  - identifier: {{ job_id | tojson }}
{% endif %}
{% endfor %}
