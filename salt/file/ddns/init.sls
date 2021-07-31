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


ddns_deps:
  pkg.installed:
  - pkgs: {{ ddns.deps | yaml }}

{{ ddns.bin }}:
  file.managed:
  - mode: 0755
  - source: salt://ddns/ddns.sh.jinja
  - template: jinja

ddns_user:
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

# Update DNS frequently, but only log errors noisily much less frequently. That
# way if there's a failure there aren't a ton of failure emails, but errors also
# don't fly under the radar long-term.
#
# TODO(https://github.com/saltstack/salt/issues/60567): Randomize these.
LOGGER_ERROR_ARGS="" {{ ddns.bin }}:
  cron.present:
  - identifier: 75b6f087-2f4b-4028-a11b-cf5cf06f7e93
  - user: {{ ddns.user }}
  - minute: "*/10"
LOGGER_ERROR_ARGS="--stderr" {{ ddns.bin }}:
  cron.present:
  - identifier: 4dd2d722-295b-4276-a886-e46f541903d6
  - user: {{ ddns.user }}
  - minute: 5
  - hour: "*/4"
