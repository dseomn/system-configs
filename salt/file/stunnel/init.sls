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


{% from 'stunnel/map.jinja' import stunnel %}


stunnel_pkgs:
  pkg.installed:
  - pkgs: {{ stunnel.pkgs | tojson }}

{{ stunnel.config_dir }} exists:
  file.exists:
  - name: {{ stunnel.config_dir }}
  - require:
    - stunnel_pkgs
{{ stunnel.config_dir }} is clean:
  file.directory:
  - name: {{ stunnel.config_dir }}
  - clean: true
  - exclude_pat:
    - README
  - require:
    - {{ stunnel.config_dir }} exists
