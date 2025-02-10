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


{% from 'cron/map.jinja' import cron_job %}


cron_pkgs:
  pkg.installed:
  - pkgs:
    - cron
  # TODO(dseomn): Remove this after finishing migration to cron_job().
  - reload_modules: true


/etc/cron.d/local:
  file.managed:
  - mode: 0600
  - source: salt://cron/crontab.jinja
  - template: jinja
  - check_cmd: crontab -n
  - require:
    - cron_pkgs


# TODO(dseomn): Remove this after finishing migration to cron_job().
root_crontab_path:
  cron.env_present:
  - name: PATH
  - value: __slot__:salt:environ.get(PATH)
  - user: root
  - require:
    - cron_pkgs


{% for state_id, kwargs in pillar.get('cron', {}).get('jobs', {}).items() %}
{{ cron_job(state_id, **kwargs) }}
{% endfor %}
