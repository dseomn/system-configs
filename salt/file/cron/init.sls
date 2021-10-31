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


root_crontab_path:
  cron.env_present:
  - name: PATH
  - value: {{ salt['environ.get']('PATH') | tojson }}
  - user: root


{% set pillar_job_id_prefix = '58623700-61fe-456a-8104-73472b24211e/' %}
{% set pillar_job_ids_by_user = {} %}
{% for username, user_jobs in pillar.get('cron', {}).get('jobs', {}).items() %}
{% set job_ids = pillar_job_ids_by_user.setdefault(username, {}) %}
{% for job_id_suffix, args in user_jobs.items() %}
{% set job_id = pillar_job_id_prefix + job_id_suffix %}
{% do job_ids.update({job_id: None}) %}
{{ job_id | tojson }}:
  cron.present:
  - user: {{ username }}
  - identifier: {{ job_id | tojson }}
  {% for arg in args %}
  - {{ arg | tojson }}
  {% endfor %}
{% endfor %}
{% endfor %}

{% for username in salt.user.list_users() %}
{% for cron_job in salt.cron.list_tab(username).crons
    if cron_job.identifier.startswith(pillar_job_id_prefix) and
    cron_job.identifier not in pillar_job_ids_by_user.get(username, {}) %}
{{ cron_job.identifier | tojson }}:
  cron.absent:
  - user: {{ username }}
  - identifier: {{ cron_job.identifier | tojson }}
{% endfor %}
{% endfor %}
