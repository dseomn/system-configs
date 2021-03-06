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

{{ ddns.conf_dir }}:
  file.directory:
  - user: root
  - group: {{ ddns.user_group }}
  - dir_mode: 0750
  - file_mode: 0640
  - recurse:
    - user
    - group
    - mode
  - clean: true

{% for provider, provider_records in pillar.ddns.items() %}

{{ ddns.conf_dir }}/{{ provider }}:
  file.directory:
  - clean: true
  - require_in:
    - file: {{ ddns.conf_dir }}

{% for record, record_data in provider_records.items() %}

{{ ddns.conf_dir }}/{{ provider }}/{{ record }}:
  file.managed:
  - contents: {{ record_data | json }}
  - require_in:
    - file: {{ ddns.conf_dir }}/{{ provider }}

{% endfor %}
{% endfor %}

cron:
  file.managed:
  - name: {{ ddns.cron_file }}
  - source: salt://ddns/ddns.cron.jinja
  - template: jinja
