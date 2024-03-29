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


{% set system = salt.grains.filter_by({
    'Debian': {
        'service': 'systemd-networkd',
        'config_directory': '/etc/systemd/network',
        'group': 'systemd-network',
        'systemd_unit_dir': '/etc/systemd/system',
        'access_point_pkgs': [
            'hostapd',
            'iw',
        ],
        'hostapd_conf_template': '/etc/hostapd/{}.conf',
        'hostapd_file_settings_dir': '/etc/hostapd/file_settings',
        'hostapd_service_template': 'hostapd@{}.service',
        'hostapd_ctrl_interface': '/var/run/hostapd',
        'wireguard_pkgs': [
            'wireguard',
        ],
    },
}) %}

{% from 'network/firewall/map.jinja' import nftables %}

{% set host = pillar.network.hosts[grains.id] %}
{% set segments = pillar.network.segments %}
{% set site = pillar.network.sites[host.site] %}
{% set global = pillar.network.global %}


include:
- network.firewall


warn about network interface changes:
  test.configurable_test_state:
  - warnings: Reboot to pick up network interface changes.


# Disable other tools that might try to configure the network.
{% if grains.os_family == 'Debian' %}
/etc/network/interfaces:
  file.managed:
  - contents: |
      # This system uses systemd-networkd to configure its interfaces.
  - onchanges_in:
    - warn about network interface changes

other network managing packages removed:
  pkg.removed:
  - pkgs:
    - netplan-generator
    - netplan.io
  - onchanges_in:
    - warn about network interface changes
{% endif %}


systemd_networkd:
  service.enabled:
  - name: {{ system.service }}

{{ system.config_directory }}:
  file.directory:
  - user: root
  - group: {{ system.group }}
  - dir_mode: 0750
  - file_mode: 0640
  - recurse:
    - user
    - group
    - mode
  - clean: true
  - onchanges_in:
    - warn about network interface changes


{% for interface_name, interface in host.interfaces.items() %}

{% if 'rename_match' in interface %}

{{ system.config_directory }}/10-{{ interface_name }}.link:
  file.managed:
  - source: salt://network/interfaces/rename-match.link.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      interface: {{ interface | tojson }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes

{% endif %}

{% endfor %}


{% set bridge_name_by_segment = {} %}
{% set wireguard_interfaces = {} %}
{% for interface_name, interface in host.interfaces.items() %}
  {% if 'wireguard' in interface %}
    {% do wireguard_interfaces.update({interface_name: interface}) %}
  {% elif 'segment' in interface %}
    {% do bridge_name_by_segment.update({interface.segment: interface_name}) %}
  {% elif 'bridge_segment' in interface %}
    {% do bridge_name_by_segment.setdefault(
        interface.bridge_segment, interface.bridge_segment) %}
  {% elif 'bridge_segments' in interface %}
    {% for segment_name in interface.bridge_segments %}
      {% do bridge_name_by_segment.setdefault(segment_name, segment_name) %}
    {% endfor %}
  {% elif 'access_point' in interface %}
    {% for segment_name in interface.access_point.segments %}
      {% do bridge_name_by_segment.setdefault(segment_name, segment_name) %}
    {% endfor %}
  {% endif %}
{% endfor %}

{% for bridge_name in bridge_name_by_segment.values() %}
{{ system.config_directory }}/10-{{ bridge_name }}.netdev:
  file.managed:
  - source: salt://network/interfaces/bridge.netdev.jinja
  - template: jinja
  - defaults:
      bridge_name: {{ bridge_name }}
      interface: {{ host.interfaces[bridge_name] | tojson }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes
{% endfor %}


{% set access_point_interfaces = {} %}

{% for interface_name, interface in host.interfaces.items() %}

{% if 'ip' in interface %}

{{ system.config_directory }}/20-{{ interface_name }}.network:
  file.managed:
  - source: salt://network/interfaces/ip-interface.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      interface: {{ interface | tojson }}
      segments: {{ segments | tojson }}
      site: {{ site | tojson }}
      global: {{ global | tojson }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes

{% elif 'bridge_segment' in interface %}

{{ system.config_directory }}/20-{{ interface_name }}.network:
  file.managed:
  - source: salt://network/interfaces/bridge-member.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      bridge_name: {{ bridge_name_by_segment[interface.bridge_segment] }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes

{% elif 'bridge_segments' in interface %}

{{ system.config_directory }}/20-{{ interface_name }}.network:
  file.managed:
  - source: salt://network/interfaces/tagged-port.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      bridge_segments: {{ interface.bridge_segments | tojson }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes
{% for segment_name in interface.bridge_segments %}
{{ system.config_directory }}/30-{{ interface_name }}.{{ segment_name }}.netdev:
  file.managed:
  - source: salt://network/interfaces/vlan.netdev.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}.{{ segment_name }}
      vlan_id: {{ segments[segment_name].id }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes
{{ system.config_directory }}/30-{{ interface_name }}.{{ segment_name }}.network:
  file.managed:
  - source: salt://network/interfaces/bridge-member.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}.{{ segment_name }}
      bridge_name: {{ bridge_name_by_segment[segment_name] }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes
{% endfor %}

{% elif 'access_point' in interface %}

{% do access_point_interfaces.update({interface_name: interface}) %}

{% endif %}

{% endfor %}


{% if access_point_interfaces %}
access_point_pkgs:
  pkg.installed:
  - pkgs: {{ system.access_point_pkgs | tojson }}

{{ system.hostapd_file_settings_dir }}:
  file.directory:
  - mode: 0700

{% for subdir in ('segments',) %}
{{ system.hostapd_file_settings_dir }}/{{ subdir }}:
  file.directory:
  - mode: 0700
  - clean: true
{% endfor %}
{% endif %}

{% set hostapd_file_settings = {} %}

{% for interface_name, interface in access_point_interfaces.items() %}

{% set hostapd_service =
    system.hostapd_service_template.format(interface_name) %}

{% set hostapd_file_settings_for_interface = {} %}
{% for segment_name in interface.access_point.segments %}
  {% for service_set_name, service_set
      in segments[segment_name].service_sets.items() %}
    {% for setting_name, setting_contents
        in service_set.get('hostapd_files', {}).items() %}
      {% do hostapd_file_settings_for_interface.update({
          'segments/{}.{}.{}'.format(
              segment_name,
              service_set_name,
              setting_name,
          ): setting_contents,
      }) %}
    {% endfor %}
  {% endfor %}
{% endfor %}
{% do hostapd_file_settings.update(hostapd_file_settings_for_interface) %}

{% if 'mac' in interface.access_point %}
{{ system.systemd_unit_dir }}/{{ hostapd_service }}.d/50-mac.conf:
  file.managed:
  - makedirs: true
  - contents: |
      [Service]
      ExecStartPre=ip link set dev {{ interface_name }} address {{ interface.access_point.mac }}
{% endif %}

{{ system.hostapd_conf_template.format(interface_name) }}:
  file.managed:
  - source: salt://network/interfaces/hostapd.conf.jinja
  - mode: 0600
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      interface: {{ interface | tojson }}
      segments: {{ segments | tojson }}
      site: {{ site | tojson }}
      bridge_name_by_segment: {{ bridge_name_by_segment | tojson }}
      file_settings_dir: {{ system.hostapd_file_settings_dir }}
      ctrl_interface: {{ system.hostapd_ctrl_interface }}

{{ hostapd_service }}_enabled:
  service.enabled:
  - name: {{ hostapd_service }}

{{ hostapd_service }}_running:
  service.running:
  - name: {{ hostapd_service }}
  - watch:
    - file: {{ system.hostapd_conf_template.format(interface_name) }}
    {% for setting_file in hostapd_file_settings_for_interface %}
    - file: {{ system.hostapd_file_settings_dir }}/{{ setting_file }}
    {% endfor %}

{% endfor %}

{% for setting_file, contents in hostapd_file_settings.items() %}
{{ system.hostapd_file_settings_dir }}/{{ setting_file }}:
  file.managed:
  - mode: 0600
  - contents: {{ contents | tojson }}
  - require_in:
    - file: {{ system.hostapd_file_settings_dir }}/{{ setting_file.rpartition('/')[0] }}
{% endfor %}


{% if wireguard_interfaces %}
wireguard_pkgs:
  pkg.installed:
  - pkgs: {{ system.wireguard_pkgs | tojson }}
{% endif %}

{% for interface_name, interface in wireguard_interfaces.items() %}

{{ system.config_directory }}/20-{{ interface_name }}.netdev:
  file.managed:
  - source: salt://network/interfaces/wireguard.netdev.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      interface: {{ interface | tojson }}
      segments: {{ segments | tojson }}
      site: {{ site | tojson }}
      global: {{ global | tojson }}
  - require_in:
    - file: {{ system.config_directory }}
  - onchanges_in:
    - warn about network interface changes

{% endfor %}


{{ nftables.config_dir }}/50-interfaces.conf:
  file.managed:
  - source: salt://network/interfaces/nftables.conf.jinja
  - template: jinja
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
