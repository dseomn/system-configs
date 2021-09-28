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


{% from 'acme/map.jinja' import acme, acme_cert %}
{% from 'apache_httpd/map.jinja' import apache_httpd %}
{% from 'common/map.jinja' import common %}


include:
- acme
- apache_httpd
- apache_httpd.acme_hooks
- apache_httpd.https


{{ common.local_share }}/web-static exists:
  file.directory:
  - name: {{ common.local_share }}/web-static
{{ common.local_share }}/web-static is clean:
  file.directory:
  - name: {{ common.local_share }}/web-static
  - clean: true
  - require:
    - {{ common.local_share }}/web-static exists

{% set dir_stack = [common.local_share, 'web-static'] %}
{% for name, contents in pillar.web.static.items() recursive %}

{% set parent_dir = '/'.join(dir_stack) %}

{% if contents is string %}

{{ parent_dir }}/{{ name }}:
  file.managed:
  - contents: {{ contents | json }}
  - require:
    - {{ parent_dir }} exists
  - require_in:
    - {{ parent_dir }} is clean

{% else %}

{{ parent_dir }}/{{ name }} exists:
  file.directory:
  - name: {{ parent_dir }}/{{ name }}
  - require:
    - {{ parent_dir }} exists
  - require_in:
    - {{ parent_dir }} is clean
{{ parent_dir }}/{{ name }} is clean:
  file.directory:
  - name: {{ parent_dir }}/{{ name }}
  - clean: true
  - require:
    - {{ parent_dir }}/{{ name }} exists

{% do dir_stack.append(name) %}
{{ loop(contents.items()) }}
{% do dir_stack.pop() %}

{% endif %}

{% endfor %}


{% for hostname in pillar.web.static %}

{{ acme_cert(hostname) }}

{{ apache_httpd.config_dir }}/sites-enabled/{{ hostname }}.conf:
  file.managed:
  - contents: |
      <VirtualHost *:443>
        ServerName {{ hostname }}

        {{ apache_httpd.port_mux_vhost_config() | indent(8) }}

        {{ apache_httpd.https_vhost_config(
            fullchain=(
                acme.certbot_config_dir + '/live/' + hostname +
                '/fullchain.pem'),
            privkey=(
                acme.certbot_config_dir + '/live/' + hostname + '/privkey.pem'),
        ) | indent(8) }}

        DocumentRoot {{ common.local_share }}/web-static/{{ hostname }}
        <Directory {{ common.local_share }}/web-static/{{ hostname }}>
          Require all granted
        </Directory>
      </VirtualHost>
  - require:
    - {{ apache_httpd.config_dir }}/sites-enabled exists
    - {{ acme.certbot_config_dir }}/live/{{ hostname }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ hostname }}/privkey.pem
    - {{ common.local_share }}/web-static/{{ hostname }} is clean
  - require_in:
    - {{ apache_httpd.config_dir }}/sites-enabled is clean
  - watch_in:
    - apache_httpd_running

{% endfor %}
