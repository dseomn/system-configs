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
- debian
- google.repo_key

{% if grains.os_family == 'Debian' and grains.osarch == 'amd64' %}
chrome:
  file.managed:
  - name: /etc/apt/sources.list.d/google-chrome.list
  - contents: |
      ### THIS FILE IS AUTOMATICALLY CONFIGURED ###
      # You may comment out this entry, but any other modifications may be lost.
      deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main
  - require:
    - sls: google.repo_key
  - require_in:
    - /etc/apt/sources.list.d is clean
  - onchanges_in:
    - apt_update
  pkg.installed:
  - name: google-chrome-stable
  - require:
    - file: chrome
    - apt_update
{% else %}
error:
  cmd.run:
  - name: 'echo "Error: Unsupported platform." >&2; exit 1'
{% endif %}
