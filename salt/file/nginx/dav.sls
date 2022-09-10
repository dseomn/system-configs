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


{% from 'nginx/map.jinja' import nginx %}


include:
- nginx


nginx_dav_pkgs:
  pkg.installed:
  - pkgs: {{ nginx.dav_pkgs | tojson }}
  - require:
    - nginx_pkgs


{{ nginx.config_dir }}/local-modules.d/50-dav.conf:
  file.managed:
  - contents: |
      load_module modules/ngx_http_dav_ext_module.so;
  - require:
    - {{ nginx.config_dir }}/local-modules.d exists
    - nginx_dav_pkgs
  - require_in:
    - {{ nginx.config_dir }}/local-modules.d is clean
  - watch_in:
    - nginx_running
