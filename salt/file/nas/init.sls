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


{% from 'acme/map.jinja' import acme_cert %}
{% from 'common/map.jinja' import common %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- acme
- virtual_machine.guest


{{ common.system_user_and_group('nas') }}

{{ acme_cert(pillar.nas.hostname, group='nas') }}

nas_share_requisites:
  test.nop:
  - require:
    {% for share in pillar.nas.shares.values() %}
    - {{ share.volume }} is mounted
    {% if share.get('backup', True) %}
    - {{ share.volume }} is backed up
    {% endif %}
    {% endfor %}
