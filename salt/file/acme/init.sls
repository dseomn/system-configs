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

{{ acme.certbot_config_dir }}/renewal:
  file.directory:
  - clean: true
  - require:
    - acme_pkgs
