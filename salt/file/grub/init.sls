# Copyright 2021 Google LLC
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


{% from 'grub/map.jinja' import grub %}


# This is meant to be referenced by other states with onchanges_in.
update-grub:
  cmd.run: []


{% if pillar.get('grub', {}).get('local_cfg') is not none %}
{{ grub.default_grub_d }}/local.cfg:
  file.managed:
  - onchanges_in:
    - update-grub
  - contents_pillar: grub:local_cfg
{% else %}
{{ grub.default_grub_d }}/local.cfg:
  file.absent:
  - onchanges_in:
    - update-grub
{% endif %}
