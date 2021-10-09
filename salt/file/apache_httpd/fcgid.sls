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


{% from 'apache_httpd/map.jinja' import apache_httpd %}


include:
- apache_httpd


apache_httpd_fcgid_pkgs:
  pkg.installed:
  - pkgs: {{ apache_httpd.fcgid_pkgs | tojson }}
  - require:
    - apache_httpd_pkgs

{{ apache_httpd.enable_mod(
    'fcgid.load', require=('apache_httpd_fcgid_pkgs',)) }}
