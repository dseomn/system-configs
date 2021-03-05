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
    },
}) %}

{% set host = pillar.network.hosts[grains.id] %}
{% set segments = pillar.network.segments %}
{% set site = pillar.network.sites[host.site] %}
{% set global = pillar.network.global %}


# Disable other tools that might try to configure the network.
{% if grains.os_family == 'Debian' %}
/etc/network/interfaces:
  file.managed:
  - contents: |
      # This system uses systemd-networkd to configure its interfaces.
{% endif %}


systemd_networkd:
  service.enabled:
  - name: {{ system.service }}

{{ system.config_directory }}:
  file.directory:
  - clean: true


{% set bridge_name_by_segment = {} %}
{% for interface_name, interface in host.interfaces.items() %}
  {% if 'segment' in interface %}
    {% do bridge_name_by_segment.update({interface.segment: interface_name}) %}
  {% elif 'bridge_segment' in interface %}
    {% do bridge_name_by_segment.setdefault(
        interface.bridge_segment, interface.bridge_segment) %}
  {% elif 'bridge_segments' in interface %}
    {% for segment_name in interface.bridge_segments %}
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
  - require_in:
    - file: {{ system.config_directory }}
{% endfor %}


{% for interface_name, interface in host.interfaces.items() %}

{% if 'ip' in interface %}

{{ system.config_directory }}/20-{{ interface_name }}.network:
  file.managed:
  - source: salt://network/interfaces/ip-interface.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      interface: {{ interface | json }}
      segments: {{ segments | json }}
      site: {{ site | json }}
      global: {{ global | json }}
  - require_in:
    - file: {{ system.config_directory }}

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

{% elif 'bridge_segments' in interface %}

{{ system.config_directory }}/20-{{ interface_name }}.network:
  file.managed:
  - source: salt://network/interfaces/tagged-port.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}
      bridge_segments: {{ interface.bridge_segments | json }}
  - require_in:
    - file: {{ system.config_directory }}
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
{{ system.config_directory }}/30-{{ interface_name }}.{{ segment_name }}.network:
  file.managed:
  - source: salt://network/interfaces/bridge-member.network.jinja
  - template: jinja
  - defaults:
      interface_name: {{ interface_name }}.{{ segment_name }}
      bridge_name: {{ bridge_name_by_segment[segment_name] }}
  - require_in:
    - file: {{ system.config_directory }}
{% endfor %}

{% endif %}

{% endfor %}
