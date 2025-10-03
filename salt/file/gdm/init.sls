# Copyright 2020 Google LLC
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


{% from 'dconf/map.jinja' import dconf %}
{% from 'gdm/map.jinja' import gdm %}


gdm:
  pkg.installed:
  - pkgs: {{ gdm.pkgs | tojson }}
  # Enable the service, but don't start it, in case starting the display manager
  # could interrupt the current session.
  service.enabled:
  - name: {{ gdm.service }}


# Leave the systemd user session running, so that the dconf.write() calls below
# can use it.
gdm linger:
  cmd.run:
  - name: loginctl enable-linger {{ gdm.user }}
  - unless:
    - |-
        [[ "$(loginctl show-user --property=Linger {{ gdm.user }})" = Linger=yes ]]
  - require:
    - gdm


{{ dconf.write(
    user=gdm.user,
    key='/org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type',
    value="'nothing'",
    require=(
        'gdm',
        'gdm linger',
    ),
) }}
{{ dconf.write(
    user=gdm.user,
    key='/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type',
    value="'nothing'",
    require=(
        'gdm',
        'gdm linger',
    ),
) }}
