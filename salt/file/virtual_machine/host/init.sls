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


{% set host = pillar.virtual_machine.host %}

{% set base_system = {
    'url': 'https://cloud.debian.org/images/cloud/bullseye/daily/20210808-728/debian-11-genericcloud-amd64-daily-20210808-728.raw',
    'hash_type': 'sha512',
    'hash': 'b855aabe6ee347274676ef7b6b36219daa9b7491f5a8d81d219d79ad091ada53aef8ef68be064b0d95a9e5c2f7991a8db7a797af069d3e57d73ea0c40d6d24f4',
    'size': '2G',
} %}


virtual_machine_host_pkgs:
  pkg.installed:
  - pkgs: {{ virtual_machine_host.pkgs | json }}
  - install_recommends: false


{% for pool_id, pool in host.thin_pools.items() %}
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


{% set _base_system_dev =
    '/dev/' + host.thin_pools.default.vg + '/base_system' %}
{% set _base_system_hash_check =
    base_system.hash_type + 'sum --check <<EOF\n' +
    base_system.hash + ' ' + _base_system_dev + '\n' +
    'EOF' %}
base_system:
  lvm.lv_present:
  - name: base_system
  - vgname: {{ host.thin_pools.default.vg }}/{{ host.thin_pools.default.lv }}
  - size: {{ base_system.size }}
  - thinvolume: true
  cmd.run:
  - name: >-
      curl --location --no-progress-meter
      -o '{{ _base_system_dev }}' '{{ base_system.url }}'
  - unless:
    - {{ _base_system_hash_check | json }}
  - check_cmd:
    - {{ _base_system_hash_check | json }}


{% for guest_id, guest in host.guests.items() %}

{% set guest_system_lv = guest.storage.system.get('lv', guest_id + '_system') %}
{% set guest_system_lv_path =
    '/dev/' + host.thin_pools.default.vg + '/' +  guest_system_lv %}

# TODO(https://github.com/saltstack/salt/issues/60691): Merge cmd.run into
# lvm.lv_present.
{{ guest_system_lv }}:
  cmd.run:
  - name: >-
      lvcreate
      --snapshot
      --setactivationskip n
      --name {{ guest_system_lv }}
      {{ host.thin_pools.default.vg }}/base_system
  - creates: {{ guest_system_lv_path }}
  - requires:
    - base_system
  lvm.lv_present:
  - vgname: {{ host.thin_pools.default.vg }}/{{ host.thin_pools.default.lv }}
  - size: {{ guest.storage.system.size }}
  - thinvolume: true
  - requires:
    - cmd: {{ guest_system_lv }}

{% endfor %}
