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


{% from 'backup/map.jinja' import backup %}
{% from 'virtual_machine/host/map.jinja' import virtual_machine_host %}

{% import_text 'users/bootstrap-passwordless-ssh-and-sudo.sh.jinja'
    as bootstrap_users %}


{% set host = pillar.virtual_machine.host %}

# TODO(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=992119): Consider using
# genericcloud instead of generic.
# TODO(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=980744): Change name to
# the appropriate stable release name instead of debiantesting.
{% set base_system = {
    'name': 'debiantesting',
    'url': 'https://cloud.debian.org/images/cloud/bookworm/20230612-1409/debian-12-generic-amd64-20230612-1409.raw',
    'hash_type': 'sha512',
    'hash': '549cc42c95dcb193a19e53cfd742bffb46280d1dbeae7aac4569297e10266afb4c8300c448e0a1c32cd1c05d164d1b9f9ddc3fe7ac50d7ad1f45acb025c7ec4c',
    'size': '2G',
} %}


{% set sls_include = [] %}
{% for guest in host.guests.values() %}
  {% for data in guest.storage.get('data', []) %}
    {% if data.get('backup', True) %}
      {% do sls_include.append('backup.source') %}
    {% endif %}
  {% endfor %}
  {% if guest.get('backup_dump') %}
    {% do sls_include.append('backup.source') %}
  {% endif %}
{% endfor %}
include: {{ sls_include | unique | tojson }}


virtual_machine_host_pkgs:
  pkg.installed:
  - pkgs: {{ virtual_machine_host.pkgs | tojson }}
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
    - {{ _base_system_hash_check | tojson }}
  - check_cmd:
    - {{ _base_system_hash_check | tojson }}


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

{% set extra_disk_paths = [] %}

{% for swap in guest.storage.get('swap', []) %}
{% set swap_vg = swap.get('vg', host.default_swap_vg) %}
{% set swap_lv = swap.get('lv', guest_id + '_swap') %}
{% set swap_path = '/dev/' + swap_vg + '/' + swap_lv %}
{% do extra_disk_paths.append(swap_path) %}
# This can't safely use lvm.lv_present, because extending the volume could
# expose data from the previously unallocated disk space to the VM.
{{ swap_path }}:
  cmd.run:
  - name: >-
      lvcreate
      --wipesignatures n
      --size {{ swap.size }}
      --name {{ swap_lv }}
      {{ swap_vg }}
      &&
      blkdiscard --zeroout {{ swap_path }}
      &&
      mkswap --uuid {{ swap.uuid }} {{ swap_path }} {{ 1024 * 1024 // 1024 }}
  - creates: {{ swap_path }}
{% endfor %}

{% for data in guest.storage.get('data', []) %}
{% set data_thin_pool_id = data.get('thin_pool', 'default') %}
{% set data_thin_pool = host.thin_pools[data_thin_pool_id] %}
{% set data_path = '/dev/' + data_thin_pool.vg + '/' + data.lv %}
{% do extra_disk_paths.append(data_path) %}
{{ data_path }}:
  cmd.run:
  - name: >-
      lvcreate
      --virtualsize {{ data.size }}
      --name {{ data.lv }}
      --thinpool {{ data_thin_pool.lv }}
      {{ data_thin_pool.vg }}
      &&
      mkfs.ext4 -U {{ data.uuid }} {{ data_path }}
  - creates: {{ data_path }}
  - require:
    - thin_pool_{{ data_thin_pool_id }}
  lvm.lv_present:
  - name: {{ data.lv }}
  - vgname: {{ data_thin_pool.vg }}/{{ data_thin_pool.lv }}
  - size: {{ data.size }}
  - thinvolume: true
  - require:
    - cmd: {{ data_path }}
{% if data.get('backup', True) %}
{{ backup.config_dir }}/source/sources.d/50-{{ data.lv }}.json:
  file.managed:
  - contents: {{
        {
            'name': data.lv,
            'type': 'lvm_thin_snapshot',
            'config': {
                'vg': data_thin_pool.vg,
                'lv': data.lv,
            },
        } | tojson | tojson
    }}
  - require:
    - create_backup_source_sources_d
    - {{ data_path }}
  - require_in:
    - manage_backup_source_sources_d
{% endif %}
{% endfor %}

{% for passthrough in guest.storage.get('passthrough', ()) %}
{% set passthrough_path = '/dev/disk/by-uuid/' + passthrough.uuid %}
{% do extra_disk_paths.append(passthrough_path) %}
{{ passthrough_path }}:
  file.exists: []
{% endfor %}

{{ guest_id }}_install:
  cmd.run:
  - name: >-
      script --quiet --return --command
      '
      virt-install
      --name {{ guest_id }}
      --vcpus {{ guest.vcpus }}
      --cpu host-passthrough,cache.mode=passthrough,migratable=off
      --memory {{ guest.memory }}
      --events on_poweroff=destroy,on_reboot=restart,on_crash=restart
      --import
      --cloud-init meta-data=<(printf "%s" "$CLOUD_INIT_META_DATA"),user-data=<(printf "%s" "$CLOUD_INIT_USER_DATA")
      --os-variant name={{ base_system.name }}
      --disk {{ guest_system_lv_path }},boot.order=1,driver.discard=unmap
      {% for extra_disk_path in extra_disk_paths -%}
      --disk {{ extra_disk_path }},driver.discard=unmap
      {% endfor -%}
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
        network-interfaces: |
          # Interfaces are configured by
          # /etc/udev/rules.d/75-cloud-ifupdown.rules and
          # /etc/network/cloud-ifupdown-helper
    - CLOUD_INIT_USER_DATA: |
        #cloud-config
        manual_cache_clean: true
        power_state:
          mode: poweroff
        runcmd:
        - [sed, -i, -e, 's/,discard,/,/', /etc/fstab]  # Use fstrim instead.
        # TODO(https://github.com/canonical/cloud-init/pull/1021): Remove the
        # next command.
        - [sed, -i, -e,
           's/^::1 \(ip6-localhost ip6-loopback\)$/::1 localhost \1/',
           /etc/hosts]
        - {{ bootstrap_users | tojson }}
        - [touch, /etc/cloud/cloud-init.disabled]
        users: []
  - require:
    - {{ guest_system_lv }}
    {% for extra_disk_path in extra_disk_paths %}
    - {{ extra_disk_path }}
    {% endfor %}
  - unless: virsh domstate --domain {{ guest_id }}
warn about {{ guest_id }}_install:
  test.configurable_test_state:
  - warnings: >-
      Add SSH host key to ~/.ssh/known_hosts, add new VM to salt/config/roster,
      and run `salt-ssh {{ guest_id }} state.apply`
  - onchanges:
    - {{ guest_id }}_install

# TODO(https://github.com/saltstack/salt/issues/60699): Manage events.
# TODO(https://github.com/saltstack/salt/issues/60700): Manage autostart.
#
# Disks are not managed here, because virt-install seems to provide better
# defaults (e.g., type="block" instead of type="file" for block device sources)
# and more options (e.g., salt doesn't seem to have a way to specify the type,
# or to configure unmap/discard).
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

{% for dump in guest.get('backup_dump', ()) %}
{% set dump_name = dump.get('name', 'dump_' + dump.source) %}
{% set dump_thin_pool_id = dump.get('thin_pool', 'default') %}
{% set dump_thin_pool = host.thin_pools[dump_thin_pool_id] %}
{{ backup.config_dir }}/source/sources.d/50-{{ dump_name }}.json:
  file.managed:
  - contents: {{
        {
            'name': dump_name,
            'type': 'virtual_machine_ssh_dump',
            'config': {
                'guest': guest_id,
                'dump_source': dump.source,
                'temp_volume_vg': dump_thin_pool.vg,
                'temp_volume_thin_pool_lv': dump_thin_pool.lv,
                'temp_volume_size': dump.size,
            },
        } | tojson | tojson
    }}
  - require:
    - create_backup_source_sources_d
    - {{ guest_id }}
    - thin_pool_{{ dump_thin_pool_id }}
  - require_in:
    - manage_backup_source_sources_d
{% endfor %}

{% endfor %}


{% for unmanaged_guest_id
    in (salt.virt.list_domains() if 'virt.list_domains' in salt else ())
    if unmanaged_guest_id not in host.guests %}
{{ unmanaged_guest_id }} is unaccounted for in salt/pillar/virtual_machine/data.yaml.jinja:
  test.fail_without_changes: []
{% endfor %}
