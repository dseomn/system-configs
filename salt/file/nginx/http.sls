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


{{ nginx.config_dir }}/local-http.d exists:
  file.directory:
  - name: {{ nginx.config_dir }}/local-http.d
  - require:
    - nginx_pkgs
{{ nginx.config_dir }}/local-http.d is clean:
  file.directory:
  - name: {{ nginx.config_dir }}/local-http.d
  - clean: true
  - require:
    - {{ nginx.config_dir }}/local-http.d exists
  - watch_in:
    - nginx_running

{{ nginx.config_dir }}/local-conf.d/10-http.conf:
  file.managed:
  - contents: |
      http {
        include {{ nginx.config_dir }}/mime.types;
        default_type application/octet-stream;
        include {{ nginx.config_dir }}/local-http.d/*;
      }
  - require:
    - {{ nginx.config_dir }}/local-conf.d exists
    - {{ nginx.config_dir }}/local-http.d exists
  - require_in:
    - {{ nginx.config_dir }}/local-conf.d is clean
  - watch_in:
    - nginx_running
