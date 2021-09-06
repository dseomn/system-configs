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

# See also
# https://docs.saltproject.io/en/latest/ref/states/all/salt.states.acme.html
# which doesn't seem to support manual auth hooks or removing renewal config for
# certs not managed by salt states.


{% from 'acme/map.jinja' import acme %}


include:
- ddns


acme_pkgs:
  pkg.installed:
  - pkgs: {{ acme.pkgs | json }}
  - require:
    # The acme packages don't actually require ddns, but states in the
    # acme_cert() macro does.
    - sls: ddns

{{ acme.certbot_config_dir }}/archive:
  file.directory:
  - mode: 0755
  - require:
    - acme_pkgs

{{ acme.certbot_config_dir }}/live:
  file.directory:
  - mode: 0755
  - require:
    - acme_pkgs

{% for clean_dir in [
    'renewal',
    'renewal-hooks/deploy',
    'renewal-hooks/post',
    'renewal-hooks/pre',
] %}
{{ acme.certbot_config_dir }}/{{ clean_dir }} exists:
  file.directory:
  - name: {{ acme.certbot_config_dir }}/{{ clean_dir }}
  - require:
    - acme_pkgs
{{ acme.certbot_config_dir }}/{{ clean_dir }} is clean:
  file.directory:
  - name: {{ acme.certbot_config_dir }}/{{ clean_dir }}
  - clean: true
  - require:
    - {{ acme.certbot_config_dir }}/{{ clean_dir }} exists
{% endfor %}
