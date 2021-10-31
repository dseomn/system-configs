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

{% import_yaml 'backup/data.yaml.jinja' as data %}

{% set source_host = data.source_hosts[grains.id] %}
{% set repository = data.repositories[source_host.repository] %}
{% set dump_hosts = {} %}
{% for dump_host_name, dump_host in data.dump_hosts.items()
    if dump_host.source == grains.id %}
  {% do dump_hosts.update({dump_host_name: dump_host}) %}
{% endfor %}

backup:
  repositories:
    {{ source_host.repository }}: {{ repository | tojson }}
  repository_hosts:
    {{ repository.primary }}: {{
        data.repository_hosts[repository.primary] | tojson }}
  source_hosts:
    {{ grains.id }}: {{ source_host | tojson }}
  dump_hosts: {{ dump_hosts | tojson }}
