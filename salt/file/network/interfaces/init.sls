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

{% set template_defaults = {
    'host': host,
    'segments': segments,
    'site': site,
    'global': global,
} %}


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

{{ system.config_directory }}/10-bridge.netdev:
  file.managed:
  - source: salt://network/interfaces/bridge.netdev
  - require_in:
    - file: {{ system.config_directory }}

{{ system.config_directory }}/10-bridge.network:
  file.managed:
  - source: salt://network/interfaces/bridge.network.jinja
  - template: jinja
  - defaults: {{ template_defaults | json }}
  - require_in:
    - file: {{ system.config_directory }}

{% for interface_name, interface in host.interfaces.items() %}

{% set template_defaults = {
    'interface_name': interface_name,
    'interface': interface,
    'host': host,
    'segments': segments,
    'site': site,
    'global': global,
} %}

{% if 'segment' in interface %}
  {% set netdev_source = 'salt://network/interfaces/segment-vif.netdev.jinja' %}
{% else %}
  {% set netdev_source = none %}
{% endif %}

{% if 'ip' in interface %}
  {% set network_source =
      'salt://network/interfaces/ip-interface.network.jinja' %}
{% elif 'bridge_segment' in interface %}
  {% set network_source =
      'salt://network/interfaces/untagged-port.network.jinja' %}
{% elif 'bridge_segments' in interface %}
  {% set network_source =
      'salt://network/interfaces/tagged-port.network.jinja' %}
{% else %}
  {% set network_source = none %}
{% endif %}

{% if not netdev_source is none %}
{{ system.config_directory }}/20-{{ interface_name }}.netdev:
  file.managed:
  - source: {{ netdev_source }}
  - template: jinja
  - defaults: {{ template_defaults | json }}
  - require_in:
    - file: {{ system.config_directory }}
{% endif %}

{% if not network_source is none %}
{{ system.config_directory }}/20-{{ interface_name }}.network:
  file.managed:
  - source: {{ network_source }}
  - template: jinja
  - defaults: {{ template_defaults | json }}
  - require_in:
    - file: {{ system.config_directory }}
{% endif %}

{% endfor %}
