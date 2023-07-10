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
        'pkgs': ('systemd-resolved',),
        'service': 'systemd-resolved',
        'config_file': '/etc/systemd/resolved.conf',
        'resolv_conf': '/etc/resolv.conf',
        'resolv_conf_target': '/run/systemd/resolve/stub-resolv.conf',
    },
}) %}


local_resolver_pkgs:
  pkg.installed:
  - pkgs: {{ system.pkgs | tojson }}

{{ system.config_file }}:
  file.managed:
  - source: salt://network/local_resolver/resolved.conf.jinja
  - template: jinja
  - require:
    - local_resolver_pkgs

{{ system.resolv_conf }}:
  file.symlink:
  - target: {{ system.resolv_conf_target }}
  - backupname: {{ system.resolv_conf }}.bak
  - require:
    - local_resolver_pkgs

systemd_resolved_enabled:
  service.enabled:
  - name: {{ system.service }}
  - require:
    - local_resolver_pkgs

systemd_resolved_running:
  service.running:
  - name: {{ system.service }}
  - require:
    - local_resolver_pkgs
  - watch:
    - file: {{ system.config_file }}
    - file: {{ system.resolv_conf }}
