# Copyright 2019 Google LLC
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


{% set plymouth = salt.grains.filter_by({
    'Debian': {
        'pkg': 'plymouth',
        'theme_pkgs': ['desktop-base', 'plymouth-label'],
        'theme': 'joy',
    },
}) %}


plymouth:
  pkg.installed:
  - name: {{ plymouth.pkg }}

plymouth_theme:
  pkg.installed:
  - pkgs: {{ plymouth.theme_pkgs | yaml }}
  cmd.run:
    # TODO: Run this only if the theme changed.
  - name: plymouth-set-default-theme --rebuild-initrd "{{ plymouth.theme }}"

{% if grains.os_family == 'Debian' %}
plymouth_grub:
  file.managed:
  - name: /etc/default/grub.d/plymouth.cfg
  - contents: |
      GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
  cmd.run:
  - name: update-grub
  - onchanges:
    - file: plymouth_grub
{% endif %}
