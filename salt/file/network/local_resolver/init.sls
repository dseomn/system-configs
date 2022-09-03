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


# TODO(Debian > 11): Figure out upgrade path from Debian 11 to 12:
# https://salsa.debian.org/systemd-team/systemd/-/blob/274ec5c99af05ba22f65c2ad101868b8f67649b1/debian/NEWS#L1-8
{% set system = salt.grains.filter_by({
    'Debian': {
        'service': 'systemd-resolved',
        'config_file': '/etc/systemd/resolved.conf',
        'resolv_conf': '/etc/resolv.conf',
        'resolv_conf_target': '/run/systemd/resolve/stub-resolv.conf',
    },
}) %}


{{ system.config_file }}:
  file.managed:
  - source: salt://network/local_resolver/resolved.conf.jinja
  - template: jinja

{{ system.resolv_conf }}:
  file.symlink:
  - target: {{ system.resolv_conf_target }}
  - backupname: {{ system.resolv_conf }}.bak

systemd_resolved_enabled:
  service.enabled:
  - name: {{ system.service }}

systemd_resolved_running:
  service.running:
  - name: {{ system.service }}
  - watch:
    - file: {{ system.config_file }}
    - file: {{ system.resolv_conf }}
