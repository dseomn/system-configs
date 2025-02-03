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

/etc/apt/keyrings/salt.asc:
  file.managed:
  - source: https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public
  - source_hash: d325a464d8651e9a79816c42a3f3f55c6e023849c6c7ff8dc8a0e029b471fdf69f73ac2ad77f92da74cbc55a69cffc71b9d9cdcd05f39f50105ecf8f9c2db2b1
  - require_in:
    - /etc/apt/keyrings
  - onchanges_in:
    - apt_update

/etc/apt/sources.list.d/50-salt.sources:
  file.managed:
  - contents: |
      Types: deb
      URIs: https://packages.broadcom.com/artifactory/saltproject-deb/
      Suites: stable
      Components: main
      Signed-By: /etc/apt/keyrings/salt.asc
  - require:
    - /etc/apt/keyrings/salt.asc
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
    - /etc/apt/sources.list.d/50-salt.sources
    - apt_update

salt-master.service:
  service.masked: []
