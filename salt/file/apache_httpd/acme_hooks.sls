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


{% from 'acme/map.jinja' import acme %}
{% from 'apache_httpd/map.jinja' import apache_httpd %}


include:
- acme


{{ acme.certbot_config_dir }}/renewal-hooks/post/50-apache-httpd:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash -e
      systemctl reload-or-restart {{ apache_httpd.service }}
  - require:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post exists
    - apache_httpd_pkgs
  - require_in:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post is clean
