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


/var/local/media-center/.config/pipewire/client-rt.conf.d/local.conf:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      stream.properties {
        channelmix.upmix = false
      }
/var/local/media-center/.config/pipewire/client.conf.d/local.conf:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      stream.properties {
        channelmix.upmix = false
      }
/var/local/media-center/.config/pipewire/pipewire-pulse.conf.d/local.conf:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - contents: |
      stream.properties {
        channelmix.upmix = false
      }


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
      Exec=systemctl --user restart {{ ' '.join((
          'pipewire-pulse.service',
          'pipewire-pulse.socket',
          'pipewire.service',
          'pipewire.socket',
          'wireplumber.service',
      )) }}


{{ media_center.stepmania_user_data_folder }}/Save/Preferences.ini:
  # TODO(https://github.com/saltstack/salt/issues/33669): Use
  # ini.options_present.
  file.keyvalue:
  - count: -1
  - key_values:
      DefaultModifiers: 'FailImmediateContinue'
      # This works around https://github.com/stepmania/stepmania/issues/1487 and
      # also makes gnome-shell recognize this as a window that can be closed
      # from the shell.
      FullscreenIsBorderlessWindow: '1'
      ShowCaution: '0'


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
        "['caffeine@patapon.info', 'drive-menu@gnome-shell-extensions.gcampax.github.com']"
      gsettings set org.gnome.shell favorite-apps \
        "[{{ media_center.favorite_apps | join(', ') }}]"
      gsettings set org.gnome.Lollypop artist-artwork false
      gsettings set org.gnome.Lollypop auto-update false
      gsettings set org.gnome.Lollypop network-access-acl \
        {{ 0b00000000001000000000 }}
      gsettings set org.gnome.Lollypop notification-flag {{ 0b11 }}
      gsettings set org.gnome.Lollypop notifications "'mpris'"
      gsettings set org.gnome.Lollypop replay-gain "'album'"
      gsettings set org.gnome.Lollypop show-tag-tracknumber true
      gsettings set org.gnome.Lollypop shown-album-lists \
        "[-4, -13, -15, -99, -101, -103]"
      gsettings set org.gnome.Lollypop transitions false
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
