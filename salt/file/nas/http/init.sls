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


{% from 'acme/map.jinja' import acme %}
{% from 'nginx/map.jinja' import nginx %}


include:
- nas
- nginx.acme_hooks
- nginx.dav
- nginx.http
- nginx.https


{{ nginx.config_dir }}/local-http.d/50-nas.conf:
  file.managed:
  - contents: |
      server {
        server_name {{ pillar.nas.hostname }};
        {{ nginx.https_server_config(
            fullchain=(
                acme.certbot_config_dir + '/live/' + pillar.nas.hostname +
                '/fullchain.pem'),
            privkey=(
                acme.certbot_config_dir + '/live/' + pillar.nas.hostname +
                '/privkey.pem'),
        ) | indent(8) }}
        location / {
          return 404;
        }
        {%- for share_name, share in pillar.nas.shares.items() %}
        location "/{{ share_name }}/" {
          alias "{{ share.volume }}/";
          autoindex on;
          dav_ext_methods PROPFIND OPTIONS;
        }
        {%- endfor %}
      }
  - require:
    - {{ nginx.config_dir }}/local-http.d exists
    - {{ acme.certbot_config_dir }}/live/{{ pillar.nas.hostname }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ pillar.nas.hostname }}/privkey.pem
    - nas_share_requisites
  - require_in:
    - {{ nginx.config_dir }}/local-http.d is clean
  - watch_in:
    - nginx_running
