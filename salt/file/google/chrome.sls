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


{% if grains.os_family != 'Debian' or grains.osarch != 'amd64' %}
  {{ raise('Unsupported platform.') }}
{% endif %}


include:
- debian
- google.repo_key


# Prevent chrome from managing the repo key:
# https://gist.github.com/jprenken/92757c76b24caec8718231205238eaf1
/etc/apt/trusted.gpg.d/google-chrome.gpg:
  file.symlink:
  - target: /dev/null
  - force: true
  - require_in:
    - /etc/apt/trusted.gpg.d is clean
  - onchanges_in:
    - apt_update

# Prevent chrome from managing the repo:
# https://www.chromium.org/developers/linux-technical-faq/
/etc/default/google-chrome:
  file.symlink:
  - target: /dev/null
  - force: true

/etc/apt/sources.list.d/50-google-chrome.sources:
  file.managed:
  - contents: |
      Types: deb
      URIs: https://dl.google.com/linux/chrome/deb
      Suites: stable
      Components: main
      Signed-By: /etc/apt/keyrings/google.asc
  - require:
    - /etc/apt/keyrings/google.asc
  - require_in:
    - /etc/apt/sources.list.d is clean
  - onchanges_in:
    - apt_update

chrome_pkgs:
  pkg.installed:
  - pkgs:
    - google-chrome-stable
  - require:
    - /etc/apt/trusted.gpg.d/google-chrome.gpg
    - /etc/default/google-chrome
    - /etc/apt/sources.list.d/50-google-chrome.sources
    - apt_update
