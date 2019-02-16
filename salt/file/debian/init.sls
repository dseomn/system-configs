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


{% set debian = salt.pillar.get(
    'debian',
    {
        'track': grains.debian.track,
        'components': 'main contrib non-free',
        'mirror': {
            'debian': 'https://deb.debian.org/debian',
            'debian-security': 'https://deb.debian.org/debian-security',
        },
    },
    merge=True,
) %}
{% do debian.setdefault('distribution', debian.track) %}


# Make sure Apt supports HTTPS URLs before making any other changes. Otherwise,
# apt can be left in a broken state once sources.list is updated to use a https
# mirror.
apt-transport-https:
  pkg.installed: []

apt.conf:
  file.managed:
  - name: /etc/apt/apt.conf
  - source: salt://debian/apt.conf.jinja2
  - template: jinja
  - defaults:
      debian: {{ debian | yaml }}

preferences:
  file.managed:
  - name: /etc/apt/preferences
  - source: salt://debian/preferences.jinja2
  - template: jinja
  - defaults:
      debian: {{ debian | yaml }}

sources.list:
  file.managed:
  - name: /etc/apt/sources.list
  - source: salt://debian/sources.list.jinja2
  - template: jinja
  - defaults:
      debian: {{ debian | yaml }}
  cmd.run:
  - name: apt-get update
  - onchanges:
    - file: sources.list
