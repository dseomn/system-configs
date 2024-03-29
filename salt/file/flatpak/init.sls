# Copyright 2022 Google LLC
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


{% from 'flatpak/map.jinja' import flatpak %}


flatpak_pkgs:
  pkg.installed:
  - pkgs: {{ flatpak.pkgs | tojson }}


{{ flatpak.remote('flathub', 'https://flathub.org/repo/flathub.flatpakrepo') }}


flatpak update --noninteractive | grep -v '^\(Nothing to do\.\)\?$' || true:
  cron.present:
  - identifier: 76a97d76-760f-4cfd-b32d-7727a88ca033
  - minute: random
  - hour: random
