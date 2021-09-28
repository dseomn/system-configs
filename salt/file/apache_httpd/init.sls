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
{% from 'port_mux/map.jinja' import port_mux %}


apache_httpd_pkgs:
  pkg.installed:
  - pkgs: {{ apache_httpd.pkgs | json }}

apache_httpd_enabled:
  service.enabled:
  - name: {{ apache_httpd.service }}
  - require:
    - apache_httpd_pkgs

apache_httpd_running:
  service.running:
  - name: {{ apache_httpd.service }}
  - require:
    - apache_httpd_pkgs

{% for enabled_dir in ('conf-enabled', 'mods-enabled', 'sites-enabled') %}
{{ apache_httpd.config_dir }}/{{ enabled_dir }} exists:
  file.exists:
  - name: {{ apache_httpd.config_dir }}/{{ enabled_dir }}
  - require:
    - apache_httpd_pkgs
{{ apache_httpd.config_dir }}/{{ enabled_dir }} is clean:
  file.directory:
  - name: {{ apache_httpd.config_dir }}/{{ enabled_dir }}
  - clean: true
  - require:
    - {{ apache_httpd.config_dir }}/{{ enabled_dir }} exists
  - watch_in:
    - apache_httpd_running
{% endfor %}

{% for conf_enabled in apache_httpd.default_conf_enabled %}
{{ apache_httpd.enable_conf(conf_enabled) }}
{% endfor %}

{{ apache_httpd.config_dir }}/conf-enabled/local.conf:
  file.managed:
  - contents: |
      StrictHostCheck ON
  - require:
    - {{ apache_httpd.config_dir }}/conf-enabled exists
  - require_in:
    - {{ apache_httpd.config_dir }}/conf-enabled is clean
  - watch_in:
    - apache_httpd_running

{% for mod_enabled in apache_httpd.default_mods_enabled %}
{{ apache_httpd.enable_mod(mod_enabled) }}
{% endfor %}

{{ apache_httpd.config_dir }}/mods-available/mime.conf:
  file.exists:
  - require:
    - apache_httpd_pkgs
{{ apache_httpd.config_dir }}/mods-enabled/mime-local.conf:
  file.managed:
  - source: salt://apache_httpd/mime-local.conf.jinja
  - template: jinja
  - require:
    - {{ apache_httpd.config_dir }}/mods-enabled exists
    - {{ apache_httpd.config_dir }}/mods-available/mime.conf
  - require_in:
    - {{ apache_httpd.config_dir }}/mods-enabled is clean
  - watch_in:
    - apache_httpd_running

{% if port_mux.has_upstream %}
{{ apache_httpd.enable_mod('remoteip.load') }}

# Don't trust information from the proxy protocol for authorization.
{{ apache_httpd.config_dir }}/mods-enabled/authz_host.load:
  file.absent:
  - require:
    - {{ apache_httpd.config_dir }}/mods-enabled is clean
  - watch_in:
    - apache_httpd_running
{% endif %}

{{ apache_httpd.config_dir }}/ports.conf.orig:
  file.copy:
  - source: {{ apache_httpd.config_dir }}/ports.conf
  - require:
    - apache_httpd_pkgs
{{ apache_httpd.config_dir }}/ports.conf:
  file.managed:
  - contents: ''
  - require:
    - {{ apache_httpd.config_dir }}/ports.conf.orig
  - watch_in:
    - apache_httpd_running
