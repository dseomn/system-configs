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


{% from 'common/map.jinja' import common %}
{% from 'crypto/map.jinja' import crypto %}
{% from 'ddns/map.jinja' import ddns %}


{% set _ddns = namespace(enable_cron=False) %}


include:
- common
- crypto.secret_rotation


ddns_deps:
  pkg.installed:
  - pkgs: {{ ddns.deps | tojson }}

{{ ddns.bin }}:
  file.managed:
  - mode: 0755
  - source: salt://ddns/ddns.sh.jinja
  - template: jinja

{{ ddns.bin_txt }}:
  file.managed:
  - mode: 0755
  - source: salt://ddns/ddns-txt.sh.jinja
  - template: jinja

{{ common.system_user_and_group('ddns') }}

{{ ddns.conf_dir }} exists:
  file.directory:
  - name: {{ ddns.conf_dir }}
  - user: root
  - group: ddns
  - dir_mode: 0750
  - require:
    - ddns user and group
{{ ddns.conf_dir }} is clean:
  file.directory:
  - name: {{ ddns.conf_dir }}
  - user: root
  - group: ddns
  - dir_mode: 0750
  - file_mode: 0640
  - recurse:
    - user
    - group
    - mode
  - clean: true
  - require:
    - {{ ddns.conf_dir }} exists

{% for provider, provider_records in pillar.ddns.items() %}

{{ ddns.conf_dir }}/{{ provider }} exists:
  file.directory:
  - name: {{ ddns.conf_dir }}/{{ provider }}
  - require:
    - {{ ddns.conf_dir }} exists
  - require_in:
    - {{ ddns.conf_dir }} is clean
{{ ddns.conf_dir }}/{{ provider }} is clean:
  file.directory:
  - name: {{ ddns.conf_dir }}/{{ provider }}
  - clean: true
  - require:
    - {{ ddns.conf_dir }}/{{ provider }} exists
  - require_in:
    - {{ ddns.conf_dir }} is clean

{% for record_name, record_value in provider_records.items() %}

{% if record_name.endswith(('.A', '.AAAA')) %}
  {% set _ddns.enable_cron = True %}
{% endif %}

{% if record_value is none %}
{{ ddns.conf_dir }}/{{ provider }}/{{ record_name }}:
  file.managed:
  - replace: false
  - contents: {{ ('password=' + crypto.generate_password()) | tojson }}
  - require:
    - {{ ddns.conf_dir }}/{{ provider }} exists
  - require_in:
    - {{ ddns.conf_dir }}/{{ provider }} is clean
{{ ddns.conf_dir }}/{{ provider }}/{{ record_name }} should be rotated:
  file.accumulated:
  - name: dynamic DNS passwords
  - filename: {{ common.local_sbin }}/monitor-secret-age
  - text: {{ ddns.conf_dir }}/{{ provider }}/{{ record_name }}
  - require:
    - {{ ddns.conf_dir }}/{{ provider }}/{{ record_name }}
  - require_in:
    - file: {{ common.local_sbin }}/monitor-secret-age
{% else %}
{{ ddns.conf_dir }}/{{ provider }}/{{ record_name }}:
  file.symlink:
  - target: {{ record_value }}
  - user: root
  - group: ddns
  - require:
    - {{ ddns.conf_dir }}/{{ provider }} exists
    - {{ ddns.conf_dir }}/{{ provider }}/{{ record_value }}
  - require_in:
    - {{ ddns.conf_dir }}/{{ provider }} is clean
{% endif %}
warn about {{ ddns.conf_dir }}/{{ provider }}/{{ record_name }}:
  test.configurable_test_state:
  - warnings: Update configuration with the dynamic DNS provider.
  - onchanges:
    - {{ ddns.conf_dir }}/{{ provider }}/{{ record_name }}

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
  - user: ddns
  - minute: "*/10"
  - commented: {{ (not _ddns.enable_cron) | tojson }}
  - require:
    - ddns user and group
    - {{ ddns.bin }}
LOGGER_ERROR_ARGS="--stderr" {{ ddns.bin }}:
  cron.present:
  - identifier: 4dd2d722-295b-4276-a886-e46f541903d6
  - user: ddns
  - minute: 5
  - hour: "*/4"
  - commented: {{ (not _ddns.enable_cron) | tojson }}
  - require:
    - ddns user and group
    - {{ ddns.bin }}
