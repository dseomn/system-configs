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

{% import_text 'users/bootstrap-passwordless-ssh-and-sudo.sh.jinja'
    as bootstrap_users %}


{% set host = pillar.virtual_machine.host %}

# TODO(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=992119): Consider using
# genericcloud instead of generic.
# TODO(Debian >= 11): Switch to a stable image.
# TODO(dseomn): Once debian11 is in osinfo-db, change the name to that.
{% set base_system = {
    'name': 'debiantesting',
    'url': 'https://cloud.debian.org/images/cloud/bullseye/daily/20210811-731/debian-11-generic-amd64-daily-20210811-731.raw',
    'hash_type': 'sha512',
    'hash': '00c495097e75ce278ba22c10f1773a633f4dd4d055e6cff8d50194d7b2c03a1f0bff8f4c12e752fb672845183e91b327caef5f463b107a0167a3df5174d79f2b',
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
  - require:
    - base_system
  lvm.lv_present:
  - vgname: {{ host.thin_pools.default.vg }}/{{ host.thin_pools.default.lv }}
  - size: {{ guest.storage.system.size }}
  - thinvolume: true
  - require:
    - cmd: {{ guest_system_lv }}

{{ guest_id }}_install:
  cmd.run:
  - name: >-
      script --quiet --return --command
      '
      virt-install
      --name {{ guest_id }}
      --vcpus {{ guest.vcpus }}
      --memory {{ guest.memory }}
      --events on_poweroff=destroy,on_reboot=restart,on_crash=restart
      --import
      --cloud-init meta-data=<(printf "%s" "$CLOUD_INIT_META_DATA"),user-data=<(printf "%s" "$CLOUD_INIT_USER_DATA")
      --boot uefi
      --os-variant name={{ base_system.name }}
      --disk {{ guest_system_lv_path }},boot.order=1
      {% for network in guest.network.values() -%}
      --network bridge={{ network.bridge }},mac={{ network.mac }}
      {% endfor -%}
      --graphics none
      --console pty,target.type=serial
      --autostart
      --noreboot
      --wait
      '
      /dev/null
  - env:
    - CLOUD_INIT_META_DATA: |
        local-hostname: {{ guest_id }}
    - CLOUD_INIT_USER_DATA: |
        #cloud-config
        manual_cache_clean: true
        power_state:
          mode: poweroff
        runcmd:
        - [sed, -i, -e, 's/,discard,/,/', /etc/fstab]  # Use fstrim instead.
        - {{ bootstrap_users | json }}
        - [touch, /etc/cloud/cloud-init.disabled]
        users: []
  - require:
    - {{ guest_system_lv }}
  - unless: virsh domstate --domain {{ guest_id }}

# TODO(https://github.com/saltstack/salt/issues/60699): Manage events.
# TODO(salt >= 3003): Manage console.
# TODO(https://github.com/saltstack/salt/issues/60700): Manage autostart.
# TODO(https://github.com/saltstack/salt/pull/60297): Manage disks.
{{ guest_id }}:
  virt.running:
  - cpu: {{ guest.vcpus }}
  - mem: {{ guest.memory }}
  - interfaces:
    {% for network_name, network in guest.network.items() %}
    - name: {{ network_name }}
      type: bridge
      source: {{ network.bridge }}
      mac: {{ network.mac }}
    {% endfor %}
  - require:
    - {{ guest_id }}_install

{% endfor %}
