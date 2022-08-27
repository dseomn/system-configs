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
{% from 'flatpak/map.jinja' import flatpak %}
{% from 'gdm/map.jinja' import gdm %}
{% from 'media_center/map.jinja' import media_center %}


include:
- common
- gdm
- gdm.custom_conf
{% if media_center.flatpak_apps %}
- flatpak
{% endif %}


{% for app in media_center.flatpak_apps %}
{{ flatpak.app('flathub', app) }}
{% endfor %}

media_center_pkgs:
  pkg.installed:
  - pkgs: {{ media_center.pkgs | tojson }}
  test.nop:
  - require:
    {% for app in media_center.flatpak_apps %}
    - flatpak app {{ app }}
    {% endfor %}

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


{% set background_image =
    '/var/local/media-center/.local/share/backgrounds/default.' +
    pillar.media_center.background.extension %}
{{ background_image }}:
  file.managed:
  - source: {{ pillar.media_center.background.url }}
  - source_hash: {{ pillar.media_center.background.hash }}
  - user: media-center
  - group: media-center
  - makedirs: true


{% for name, target
    in salt['pillar.get']('media_center:home_symlinks', {}).items() %}
/var/local/media-center/{{ name }}:
  file.symlink:
  - target: {{ target }}
  - force: true
  - makedirs: true
  - user: media-center
  - group: media-center
{% endfor %}


/var/local/media-center/.config/pulse/daemon.conf:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      remixing-use-all-sink-channels = no


/var/local/media-center/.local/bin/leave-a-note:
  file.managed:
  - user: media-center
  - group: media-center
  - mode: 0755
  - makedirs: true
  - contents: |
      #!/bin/bash -e
      if mail --subject='note from media center' root; then
        printf '%s' 'Sent. Press Enter to continue.'
      else
        printf '%s' "ERROR: mail returned $?."
      fi
      read -r x
/var/local/media-center/.local/share/applications/leave-a-note.desktop:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      [Desktop Entry]
      Type=Application
      Name=Leave a Note
      Icon=mail-send
      Exec=/var/local/media-center/.local/bin/leave-a-note
      Terminal=true


/var/local/media-center/.local/share/applications/fix-audio.desktop:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      [Desktop Entry]
      Type=Application
      Name=Fix Audio
      Icon=audio-speakers-symbolic
      Exec=pulseaudio --kill


# https://github.com/stepmania/stepmania/issues/1487 prevents the keyboard from
# working in fullscreen, and gnome-shell also doesn't seem to recognize
# stepmania as a window that can be closed from the shell. This desktop file
# makes it easier to close stepmania if there are any issues with the dance pad
# or if it's unplugged.
/var/local/media-center/.local/share/applications/exit-stepmania.desktop:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      [Desktop Entry]
      Type=Application
      Name=Exit StepMania
      Exec=killall stepmania


/var/local/media-center/.local/bin/autostart:
  file.managed:
  - user: media-center
  - group: media-center
  - mode: 0755
  - makedirs: true
  - contents: |
      #!/bin/bash -e
      gsettings set org.gnome.desktop.background picture-uri \
        "'file://{{ background_image }}'"
      gsettings set org.gnome.desktop.screensaver lock-enabled false
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-ac-type "'nothing'"
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-battery-type "'nothing'"
      gsettings set org.gnome.shell enabled-extensions \
        "['caffeine@patapon.info']"
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
