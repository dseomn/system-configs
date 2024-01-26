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
{% from 'network/firewall/map.jinja' import nftables %}


include:
- common
- gdm
- gdm.custom_conf
- network.firewall
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


{{ media_center.firefox_config_dir }}/local.js:
  file.managed:
  - contents: |
      pref("browser.aboutwelcome.enabled", false, locked);
      pref("browser.download.always_ask_before_handling_new_types", true, locked);
      pref("browser.download.start_downloads_in_tmp_dir", true, locked);
      pref("browser.download.useDownloadDir", false, locked);
      pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false, locked);
      pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false, locked);
      pref("browser.newtabpage.enabled", false, locked);
      pref("browser.startup.homepage", "chrome://browser/content/blanktab.html", locked);
      pref("browser.urlbar.suggest.quicksuggest.sponsored", false, locked);
      pref("extensions.formautofill.addresses.enabled", false, locked);
      pref("extensions.formautofill.creditCards.enabled", false, locked);
      pref("privacy.clearOnShutdown.cache", true, locked);
      pref("privacy.clearOnShutdown.cookies", true, locked);
      pref("privacy.clearOnShutdown.downloads", true, locked);
      pref("privacy.clearOnShutdown.formdata", true, locked);
      pref("privacy.clearOnShutdown.history", true, locked);
      pref("privacy.clearOnShutdown.offlineApps", true, locked);
      pref("privacy.clearOnShutdown.openWindows", true, locked);
      pref("privacy.clearOnShutdown.sessions", true, locked);
      pref("privacy.clearOnShutdown.siteSettings", true, locked);
      pref("privacy.history.custom", true, locked);
      pref("privacy.sanitize.sanitizeOnShutdown", true, locked);
      pref("signon.rememberSignons", false, locked);
  - require:
    - media_center_pkgs

{% load_yaml as firefox_policies %}
policies:
  Bookmarks: {{
      salt['pillar.get']('media_center:firefox_bookmarks', ()) | tojson
  }}
  NoDefaultBookmarks: true
{% endload %}
{{ media_center.firefox_policies_file }}:
  file.managed:
  - makedirs: true
  - contents: {{ firefox_policies | tojson(indent=2, sort_keys=True) | tojson }}
  - require:
    - media_center_pkgs


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


/var/local/media-center/.mpd:
  file.directory:
  - user: media-center
  - group: media-center
  - require:
    - media-center user and group
/var/local/media-center/.config/mpd/mpd.conf:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - require:
    - media-center user and group
    - /var/local/media-center/.mpd
  - contents: |
      db_file "~/.mpd/database"
      state_file "~/.mpd/state"
      restore_paused "yes"
      follow_outside_symlinks "yes"
      follow_inside_symlinks "yes"
      replaygain "album"
      audio_output {
        name "default"
        # TODO(mpd >= 0.23.13): Try switching to pipewire. With mpd 0.23.12 I
        # was getting the error below which looks like it might be related to
        # https://github.com/MusicPlayerDaemon/MPD/issues/1812 and
        # https://github.com/MusicPlayerDaemon/MPD/issues/1753.
        #
        # 'builder->data == ((void *)0) || builder->state.offset < sizeof(struct spa_pod) || builder->state.offset == ((uint64_t)sizeof(struct spa_pod) + (((struct spa_pod*)(pod))->size))' failed at ../src/modules/module-protocol-native.c:1395 assert_single_pod()
        type "pulse"
      }

{{ nftables.config_dir }}/50-mpd.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport 6600 accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes

mpd_system_service:
  service.dead:
  - name: mpd.service
  - enable: false
  - require:
    - media_center_pkgs
mpd_user_service:
  cmd.run:
  - name: systemctl --machine=media-center@ --user enable mpd.service
  - unless: systemctl --machine=media-center@ --user is-enabled mpd.service
  - require:
    - media-center user and group
    - media_center_pkgs
    - /var/local/media-center/.config/mpd/mpd.conf

/var/local/media-center/.config/mpDris2/mpDris2.conf:
  file.managed:
  - user: media-center
  - group: media-center
  - makedirs: true
  - require:
    - media-center user and group
  - contents: |
      [Bling]
      mmkeys = True
      notify = False
/etc/systemd/user/mpDris2.service.d/50-salt-media-center.conf:
  file.managed:
  - makedirs: true
  - contents: |
      [Unit]
      # Override Debian's ConditionUser=!@system which prevents media-center
      # from running this service.
      ConditionUser=
mpdris2_global_user_service:
  cmd.run:
  - name: systemctl --global disable mpDris2.service
  - onlyif: systemctl --global is-enabled mpDris2.service
  - require:
    - media_center_pkgs
mpdris2_user_service:
  cmd.run:
  - name: systemctl --machine=media-center@ --user enable mpDris2.service
  - unless: systemctl --machine=media-center@ --user is-enabled mpDris2.service
  - require:
    - media-center user and group
    - media_center_pkgs
    - /var/local/media-center/.config/mpDris2/mpDris2.conf

/etc/mpdscribble.conf:
  file.managed:
  - user: root
  - group: mpdscribble
  - mode: 0640
  - require:
    - media_center_pkgs
  - contents: |
      {% for scrobbler_name, scrobbler_config in
          pillar.media_center.get('mpdscribble', {}).get('scrobblers', {}).items() %}
      [{{ scrobbler_name}}]
      journal = /var/cache/mpdscribble/{{ scrobbler_name }}.journal
      {{ scrobbler_config | indent(6) }}
      {% endfor %}
mpdscribble_global_user_service:
  cmd.run:
  - name: systemctl --global disable mpdscribble.service
  - onlyif: systemctl --global is-enabled mpdscribble.service
  - require:
    - media_center_pkgs
mpdscribble_enabled:
  service.enabled:
  - name: mpdscribble.service
  - require:
    - media_center_pkgs
mpdscribble_running:
  service.running:
  - name: mpdscribble.service
  - watch:
    - /etc/mpdscribble.conf


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
      gsettings set org.gnome.desktop.session idle-delay 0
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-ac-type "'nothing'"
      gsettings set org.gnome.settings-daemon.plugins.power \
        sleep-inactive-battery-type "'nothing'"
      gsettings set org.gnome.shell enabled-extensions \
        "['drive-menu@gnome-shell-extensions.gcampax.github.com']"
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
