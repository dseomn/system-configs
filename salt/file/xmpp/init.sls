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
{% from 'xmpp/map.jinja' import xmpp %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- backup.dump
- virtual_machine.guest


xmpp_pkgs:
  pkg.installed:
  - pkgs: {{ xmpp.pkgs }}


# TODO(dseomn): Configure ejabberd.
# TODO(dseomn): service.enabled and service.running

{{ common.local_lib }}/backup/dump/sources/ejabberd:
  file.managed:
  - source: salt://xmpp/dump.py
  - mode: 0755
  - require:
    - {{ common.local_lib }}/backup/dump/sources exists
    - {{ common.local_lib }}/backup/dump/sources/ejabberd is dumped
    - xmpp_pkgs
  - require_in:
    - {{ common.local_lib }}/backup/dump/sources is clean
