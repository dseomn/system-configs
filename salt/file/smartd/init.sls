# Copyright 2019 Google LLC
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
{% from 'cron/map.jinja' import cron_job, stable_random_int %}


{% set smartd = {
    'Debian': {
        'pkg': 'smartmontools',
        'config_file': '/etc/smartd.conf',
        'service': 'smartmontools',
    },
}[grains.os_family] %}


smartd_pkgs:
  pkg.installed:
  - name: {{ smartd.pkg }}


smartd_enabled:
  service.enabled:
  - name: {{ smartd.service }}
  - require:
    - smartd_pkgs
smartd_running:
  service.running:
  - name: {{ smartd.service }}
  - require:
    - smartd_pkgs

{% set test_day =
    stable_random_int(1, 7, seed=(grains.id, 'smart-long-test-day-of-week'))
%}
{% set test_hour =
    '{:02d}'.format(
        stable_random_int(0, 23, seed=(grains.id, 'smart-long-test-hour')) | int
    )
%}
{{ smartd.config_file }}:
  file.managed:
  - contents: |
      DEVICESCAN \
        -d removable \
        -n standby,48 \
        -s L/../../{{ test_day }}/{{ test_hour }}:005-167 \
        -m root \
        -M daily \
        -a
  - require:
    - smartd_pkgs
  - watch_in:
    - smartd_running


{{ common.local_sbin }}/smart-report:
  file.managed:
  - source: salt://smartd/report.py
  - mode: 0755
  - require:
    - smartd_pkgs

{{ cron_job(
    state_id='smart-report cron',
    user='root',
    command=common.local_sbin + '/smart-report',
    minute='?',
    hour='?',
    day_of_month='?',
    month='?',
    require=(
        common.local_sbin + '/smart-report',
    ),
) }}
