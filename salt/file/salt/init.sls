# Copyright 2024 Google LLC
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


include:
- debian


# https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/debian.html

# Salt doesn't seem to provide packages for testing/unstable, so use the latest
# stable version they do offer packages for.
{% set debian = {
    ('Debian', None): {'number': '12', 'name': 'bookworm'},
}[(grains.os, grains.get('osmajorrelease'))] %}

/etc/apt/keyrings/salt.gpg:
  file.managed:
  - source: https://repo.saltproject.io/salt/py3/src/SALT-PROJECT-GPG-PUBKEY-2023.gpg
  - source_hash: b60cfe38c5e854f0bdaa61d5fcd638c35d2b7613547e8cbf442402ff02f9d5fb3f1c22a97ca9afe2ecd7831d39fd2535ad6336e28e1f2b54815f5dabcfd8b7ca

/etc/apt/sources.list.d/salt.sources:
  file.managed:
  - contents: |
      Types: deb deb-src
      URIs: https://repo.saltproject.io/salt/py3/debian/{{ debian.number }}/{{ grains.osarch }}/latest
      Suites: {{ debian.name }}
      Components: main
      Signed-By: /etc/apt/keyrings/salt.gpg
  - require:
    - /etc/apt/keyrings/salt.gpg
  - require_in:
    - /etc/apt/sources.list.d is clean
  - onchanges_in:
    - apt_update

salt_pkgs:
  pkg.installed:
  - pkgs:
    - salt-master  # for salt-run
    - salt-ssh
  - require:
    - /etc/apt/sources.list.d/salt.sources
    - apt_update

salt-master.service:
  service.masked: []
