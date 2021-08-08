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


{% from 'virtual_machine/host/map.jinja' import virtual_machine_host %}


virtual_machine_host_pkgs:
  pkg.installed:
  - pkgs: {{ virtual_machine_host.pkgs | json }}


{% for pool_id, pool in pillar.virtual_machine.host.thin_pools.items() %}
thin_pool_{{ pool_id }}:
  lvm.lv_present:
  - name: {{ pool.lv }}
  - vgname: {{ pool.vg }}
  - size: {{ pool.size }}
  - thinpool: true

# TODO(https://github.com/saltstack/salt/pull/60683): Merge this into the state
# above.
lvchange --errorwhenfull y {{ pool.vg }}/{{ pool.lv }}:
  cmd.run:
  - onchanges:
    - thin_pool_{{ pool_id }}
{% endfor %}
