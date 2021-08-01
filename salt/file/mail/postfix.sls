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


{% from 'mail/map.jinja' import mail %}


include:
- mail


postfix_pkg:
  pkg.installed:
  - name: {{ mail.postfix.pkg }}

postfix_enabled:
  service.enabled:
  - name: {{ mail.postfix.service }}
  - require:
    - postfix_pkg

postfix_running:
  service.running:
  - name: {{ mail.postfix.service }}
  - require:
    - postfix_pkg


newaliases:
  cmd.run:
  - require:
    - postfix_pkg
  - onchanges:
    - /etc/aliases
