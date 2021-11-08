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
{% from 'kodi/map.jinja' import kodi %}


include:
- common
- gdm
- gdm.custom_conf


kodi_pkgs:
  pkg.installed:
  - pkgs: {{ kodi.pkgs | tojson }}

{% for service in kodi.masked_services %}
{{ service }} is masked:
  service.masked:
  - name: {{ service }}
  - require:
    - kodi_pkgs
{% endfor %}


{{ common.system_user_and_group(
    'kodi',
    groups=kodi.user_groups,
    home='/var/local/kodi',
    createhome=True,
    shell=None,
) }}

kodi autologin:
  file.accumulated:
  - name: daemon
  - filename: {{ gdm.config_dir }}/{{ gdm.custom_conf }}
  - text:
    - AutomaticLoginEnable=true
    - AutomaticLogin=kodi
    - TimedLoginEnable=true
    - TimedLogin=kodi
  - require:
    - kodi user and group
  - require_in:
    - file: {{ gdm.config_dir }}/{{ gdm.custom_conf }}


/var/local/kodi/.local/bin/autostart:
  file.managed:
  - user: kodi
  - group: kodi
  - mode: 0755
  - makedirs: true
  - contents: |
      #!/bin/bash -e
      gsettings set org.gnome.desktop.screensaver lock-enabled false
      gsettings set org.gnome.settings-daemon.plugins.media-keys next-static \
        '[]'
      gsettings set org.gnome.settings-daemon.plugins.media-keys play-static \
        '[]'
      gsettings set org.gnome.settings-daemon.plugins.media-keys \
        previous-static '[]'
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-ac-type "'nothing'"
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-battery-type "'nothing'"
      gsettings set org.gnome.shell favorite-apps "['kodi.desktop']"
      kodi &
      sleep 10
      kodi-send \
        --action='Skin.SetBool(homemenunofavbutton)' \
        --action='Skin.SetBool(homemenunogamesbutton)' \
        --action='Skin.SetBool(homemenunomoviebutton)' \
        --action='Skin.SetBool(homemenunomusicvideobutton)' \
        --action='Skin.SetBool(homemenunopicturesbutton)' \
        --action='Skin.SetBool(homemenunoprogramsbutton)' \
        --action='Skin.SetBool(homemenunoradiobutton)' \
        --action='Skin.SetBool(homemenunotvbutton)' \
        --action='Skin.SetBool(homemenunotvshowbutton)' \
        --action='Skin.SetBool(homemenunoweatherbutton)'
      wait
  - require:
    - kodi user and group
    - kodi_pkgs
/var/local/kodi/.config/autostart/autostart.desktop:
  file.managed:
  - user: kodi
  - group: kodi
  - makedirs: true
  - contents: |
      [Desktop Entry]
      Type=Application
      Name=autostart
      Exec=/var/local/kodi/.local/bin/autostart
  - require:
    - /var/local/kodi/.local/bin/autostart


/var/local/kodi/.kodi/userdata/advancedsettings.xml:
  file.managed:
  - source: salt://kodi/advancedsettings.xml.jinja
  - user: kodi
  - group: kodi
  - template: jinja
  - makedirs: true
  - require:
    - kodi user and group
    - kodi_pkgs
