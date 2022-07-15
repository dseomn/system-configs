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


{% from 'common/map.jinja' import common %}
{% from 'gdm/map.jinja' import gdm %}
{% from 'media_center/map.jinja' import media_center %}


include:
- common
- gdm
- gdm.custom_conf


media_center_pkgs:
  pkg.installed:
  - pkgs: {{ media_center.pkgs | tojson }}

{% for service in media_center.masked_services %}
{{ service }} is masked:
  service.masked:
  - name: {{ service }}
  - require:
    - media_center_pkgs
{% endfor %}


{{ common.system_user_and_group(
    'media-center',
    groups=media_center.user_groups,
    home='/var/local/media-center',
    createhome=True,
    shell=None,
) }}

media-center autologin:
  file.accumulated:
  - name: daemon
  - filename: {{ gdm.config_dir }}/{{ gdm.custom_conf }}
  - text:
    - AutomaticLoginEnable=true
    - AutomaticLogin=media-center
    - TimedLoginEnable=true
    - TimedLogin=media-center
  - require:
    - media-center user and group
  - require_in:
    - file: {{ gdm.config_dir }}/{{ gdm.custom_conf }}


/var/local/media-center/.local/bin/autostart:
  file.managed:
  - user: media-center
  - group: media-center
  - mode: 0755
  - makedirs: true
  - contents: |
      #!/bin/bash -e
      gsettings set org.gnome.desktop.screensaver lock-enabled false
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-ac-type "'nothing'"
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-battery-type "'nothing'"
      gsettings set org.gnome.shell favorite-apps \
        "[{{ media_center.favorite_apps | join(', ') }}]"
  - require:
    - media-center user and group
    - media_center_pkgs
/var/local/media-center/.config/autostart/autostart.desktop:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      [Desktop Entry]
      Type=Application
      Name=autostart
      Exec=/var/local/media-center/.local/bin/autostart
  - require:
    - /var/local/media-center/.local/bin/autostart
