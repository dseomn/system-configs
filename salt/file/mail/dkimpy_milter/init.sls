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
{% from 'mail/dkimpy_milter/map.jinja' import dkimpy_milter %}
{% from 'mail/map.jinja' import mail %}


include:
- mail


dkimpy_milter_pkgs:
  pkg.installed:
  - pkgs: {{ dkimpy_milter.pkgs | tojson }}

dkimpy_milter_enabled:
  service.enabled:
  - name: {{ dkimpy_milter.service }}
  - require:
    - dkimpy_milter_pkgs

dkimpy_milter_running:
  service.running:
  - name: {{ dkimpy_milter.service }}
  - require:
    - dkimpy_milter_pkgs

# Let postfix connect to dkimpy-milter's unix sockets.
{{ common.user_in_group(
    user=mail.postfix_user,
    group=dkimpy_milter.group,
    require=('mail_pkgs', 'dkimpy_milter_pkgs'),
    watch_in=('postfix_running',),
) }}

{{ dkimpy_milter.config_dir }} exists:
  file.directory:
  - name: {{ dkimpy_milter.config_dir }}
  - group: {{ dkimpy_milter.group }}
  - dir_mode: 0750
  - require:
    - dkimpy_milter_pkgs
{{ dkimpy_milter.config_dir }} is clean:
  file.directory:
  - name: {{ dkimpy_milter.config_dir }}
  - clean: true
  - require:
    - {{ dkimpy_milter.config_dir }} exists
