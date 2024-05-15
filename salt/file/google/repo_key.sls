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
  - source_hash: 0ccf8f2f4396f5acee4e7cd7a3e8e1c83233fc17c2e4785d82c71b887c3cacd2faf0feae50d6f42fc5e86d2b492d7a88c8a31720ace591b3b62326176c4ca6d2
  - require_in:
    - /etc/apt/keyrings
  - onchanges_in:
    - apt_update
