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


{% from 'ddns/map.jinja' import ddns %}


deps:
  pkg.installed:
  - pkgs: {{ ddns.deps | yaml }}

bin:
  file.managed:
  - name: {{ ddns.bin }}
  - mode: 0755
  - source: salt://ddns/ddns.sh.jinja
  - template: jinja

user:
  group.present:
  - name: {{ ddns.user_group }}
  - system: true
  user.present:
  - name: {{ ddns.user }}
  - gid: {{ ddns.user_group }}
  - home: {{ ddns.user_home }}
  - createhome: false
  - shell: {{ ddns.user_shell }}
  - system: true

{% for subdir in [''] + ddns.providers %}
{% set directory = ddns.conf_dir + ('/' if subdir else '') + subdir %}
{{ directory }}:
  file.directory:
  - user: root
  - group: {{ ddns.user_group }}
  - mode: 0750
{% endfor %}

cron:
  file.managed:
  - name: {{ ddns.cron_file }}
  - source: salt://ddns/ddns.cron.jinja
  - template: jinja
