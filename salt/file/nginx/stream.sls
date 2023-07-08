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


{% from 'nginx/map.jinja' import nginx %}


include:
- nginx


nginx_stream_pkgs:
  pkg.installed:
  - pkgs: {{ nginx.stream_pkgs | tojson }}
  - require:
    - nginx_pkgs


{{ nginx.config_dir }}/local-modules.d/20-stream.conf:
  file.managed:
  - contents: |
      load_module modules/ngx_stream_module.so;
  - require:
    - {{ nginx.config_dir }}/local-modules.d exists
    - nginx_stream_pkgs
  - require_in:
    - {{ nginx.config_dir }}/local-modules.d is clean
  - watch_in:
    - nginx_running

{{ nginx.config_dir }}/local-stream.d exists:
  file.directory:
  - name: {{ nginx.config_dir }}/local-stream.d
  - require:
    - nginx_pkgs
{{ nginx.config_dir }}/local-stream.d is clean:
  file.directory:
  - name: {{ nginx.config_dir }}/local-stream.d
  - clean: true
  - require:
    - {{ nginx.config_dir }}/local-stream.d exists
  - watch_in:
    - nginx_running

{{ nginx.config_dir }}/local-conf.d/10-stream.conf:
  file.managed:
  - contents: |
      stream {
        include {{ nginx.config_dir }}/local-stream.d/*;
      }
  - require:
    - {{ nginx.config_dir }}/local-conf.d exists
    - {{ nginx.config_dir }}/local-stream.d exists
  - require_in:
    - {{ nginx.config_dir }}/local-conf.d is clean
  - watch_in:
    - nginx_running
