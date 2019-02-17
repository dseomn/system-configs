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


include:
- google.repo_key

{% if grains.os_family == 'Debian' and grains.osarch == 'amd64' %}
chrome:
  pkgrepo.managed:
  - name: |
      deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
  - file: /etc/apt/sources.list.d/google-chrome.list
  - require:
    - sls: google.repo_key
  pkg.installed:
  - name: google-chrome-stable
{% else %}
error:
  cmd.run:
  - name: 'echo "Error: Unsupported platform." >&2; exit 1'
{% endif %}
