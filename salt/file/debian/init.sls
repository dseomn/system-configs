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


preferences:
  file.managed:
  - name: /etc/apt/preferences
  - source: salt://debian/preferences.jinja
  - template: jinja

apt_update:
  cmd.run:
  - name: apt-get update

/etc/apt/sources.list:
  file.managed:
  - source: salt://debian/sources.list.jinja
  - template: jinja
  - onchanges_in:
    - apt_update

/etc/apt/sources.list.d is clean:
  file.directory:
  - name: /etc/apt/sources.list.d
  - clean: true
  - onchanges_in:
    - apt_update
