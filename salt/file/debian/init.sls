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


{% from 'debian/map.jinja' import debian %}


preferences:
  file.managed:
  - name: /etc/apt/preferences
  - source: salt://debian/preferences.jinja
  - template: jinja

apt_update:
  cmd.run:
  - name: apt-get update

/etc/apt/trusted.gpg.d is clean:
  file.directory:
  - name: /etc/apt/trusted.gpg.d
  - clean: true
  - exclude_pat:
    - debian-archive-*
  - onchanges_in:
    - apt_update

/etc/apt/keyrings is clean:
  file.directory:
  - name: /etc/apt/keyrings
  - clean: true
  - onchanges_in:
    - apt_update

/etc/apt/sources.list:
  file.absent:
  - onchanges_in:
    - apt_update

/etc/apt/sources.list.d is clean:
  file.directory:
  - name: /etc/apt/sources.list.d
  - clean: true
  - onchanges_in:
    - apt_update

/etc/apt/sources.list.d/20-debian.sources:
  file.managed:
  - contents: |
      Types: deb deb-src
      URIs: {{ debian.mirror['debian'] }}
      Suites: {{ ' '.join(
          [debian.distribution] +
          (
              [
                  debian.distribution + '-updates',
                  debian.distribution + '-backports',
              ]
              if debian.track == 'stable'
              else []
          ) +
          debian.additional_distributions
      ) }}
      Components: {{ debian.components }}
      Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

      {% if debian.track != 'unstable' %}
      Types: deb deb-src
      URIs: {{ debian.mirror['debian-security'] }}
      Suites: {{ debian.distribution + '-security' }}
      Components: {{ debian.components }}
      Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
      {% endif %}
  - require_in:
    - /etc/apt/sources.list.d is clean
  - onchanges_in:
    - apt_update
