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


nginx_pkgs:
  pkg.installed:
  - pkgs: {{ nginx.pkgs | json }}

nginx_enabled:
  service.enabled:
  - name: {{ nginx.service }}
  - require:
    - nginx_pkgs

nginx_running:
  service.running:
  - name: {{ nginx.service }}
  - require:
    - nginx_pkgs

{{ nginx.config_dir }}/local-modules.d exists:
  file.directory:
  - name: {{ nginx.config_dir }}/local-modules.d
  - require:
    - nginx_pkgs
{{ nginx.config_dir }}/local-modules.d is clean:
  file.directory:
  - name: {{ nginx.config_dir }}/local-modules.d
  - clean: true
  - require:
    - {{ nginx.config_dir }}/local-modules.d exists
  - watch_in:
    - nginx_running

{{ nginx.config_dir }}/local-conf.d exists:
  file.directory:
  - name: {{ nginx.config_dir }}/local-conf.d
  - require:
    - nginx_pkgs
{{ nginx.config_dir }}/local-conf.d is clean:
  file.directory:
  - name: {{ nginx.config_dir }}/local-conf.d
  - clean: true
  - require:
    - {{ nginx.config_dir }}/local-conf.d exists
  - watch_in:
    - nginx_running

{{ nginx.config_dir }}/nginx.conf.orig:
  file.copy:
  - source: {{ nginx.config_dir }}/nginx.conf
  - require:
    - nginx_pkgs
{{ nginx.config_dir }}/nginx.conf:
  file.managed:
  - contents: |
      user {{ nginx.user }};
      pid {{ nginx.pid_file }};
      worker_processes auto;
      include {{ nginx.config_dir }}/local-modules.d/*;
      events {
      }
      include {{ nginx.config_dir }}/local-conf.d/*;
  - require:
    - {{ nginx.config_dir }}/nginx.conf.orig
    - {{ nginx.config_dir }}/local-modules.d exists
    - {{ nginx.config_dir }}/local-conf.d exists
  - watch_in:
    - nginx_running
