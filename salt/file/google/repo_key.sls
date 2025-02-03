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


{% if grains.os_family != 'Debian' %}
  {{ raise('Unsupported platform.') }}
{% endif %}


include:
- debian


# https://www.google.com/linuxrepositories/
/etc/apt/keyrings/google.asc:
  file.managed:
  - source: https://dl.google.com/linux/linux_signing_key.pub
  - source_hash: 7c3ac565990f83b20d30ad5a91027b75c5521adb05dcfe253f83535b1f7a4d47eadac194a88ab3ab691c5654b0f6ba8da73e36a1be4fba346722d2d507edf61b
  - require_in:
    - /etc/apt/keyrings
  - onchanges_in:
    - apt_update
