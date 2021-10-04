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
{% from 'common/map.jinja' import common %}
{% from 'crypto/map.jinja' import crypto %}
{% from 'nas/map.jinja' import nas %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'stunnel/map.jinja' import stunnel %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


{% set share_requisites = [] %}
{% for share in pillar.nas.shares.values() %}
  {% do share_requisites.append(share.volume + ' is mounted') %}
  {% if share.get('backup', True) %}
    {% do share_requisites.append(share.volume + ' is backed up') %}
  {% endif %}
{% endfor %}

{% set new_cert_reload_services = [] %}
{% set open_tcp_ports = [] %}


include:
- acme
- network.firewall
- stunnel
- virtual_machine.guest


nas_pkgs:
  pkg.installed:
  - pkgs: {{ nas.pkgs | tojson }}

nas_user:
  group.present:
  - name: nas
  - system: true
  user.present:
  - name: nas
  - gid: nas
  - home: {{ common.nonexistent_path }}
  - createhome: false
  - shell: {{ common.nologin_shell }}
  - system: true
  - require:
    - group: nas_user

{{ acme_cert(pillar.nas.hostname, group='nas') }}


{{ nas.rsync_config_file }}:
  file.managed:
  - contents: |
      daemon uid = nas
      daemon gid = nas
      use chroot = false
      read only = true
      ignore nonreadable = true
      {% for share_name, share in pillar.nas.shares.items() %}
      [{{ share_name }}]
      path = {{ share.volume.replace('%', '%%') }}
      {% endfor %}
  - require: {{ (['nas_user'] + share_requisites) | tojson }}

{% do open_tcp_ports.append(873) %}

rsync_enabled:
  service.enabled:
  - name: {{ nas.rsync_service }}

rsync_running:
  service.running:
  - name: {{ nas.rsync_service }}
  - watch:
    - {{ nas.rsync_config_file }}

{{ stunnel.config_dir }}/rsync.conf:
  file.managed:
  - contents: |
      {{ stunnel.boilerplate | indent(6) }}
      setuid = nas
      setgid = nas
      [rsync_tls]
      accept = :::874
      cert = {{ acme.certbot_config_dir }}/live/{{ pillar.nas.hostname }}/fullchain.pem
      key = {{ acme.certbot_config_dir }}/live/{{ pillar.nas.hostname }}/privkey.pem
      sslVersionMin = {{ crypto.openssl.general_protocols_min }}
      ciphers = {{ crypto.openssl.ciphers_to_string(crypto.openssl.general_ciphers) }}
      connect = localhost:873
  - require:
    - {{ stunnel.config_dir }} exists
    - nas_user
    - {{ acme.certbot_config_dir }}/live/{{ pillar.nas.hostname }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ pillar.nas.hostname }}/privkey.pem
    - rsync_enabled
    - rsync_running
  - require_in:
    - {{ stunnel.config_dir }} is clean

{% do open_tcp_ports.append(874) %}

rsync_stunnel_enabled:
  service.enabled:
  - name: {{ stunnel.service_instance('rsync') }}

rsync_stunnel_running:
  service.running:
  - name: {{ stunnel.service_instance('rsync') }}
  - watch:
    - {{ stunnel.config_dir }}/rsync.conf

{% do new_cert_reload_services.append(stunnel.service_instance('rsync')) %}


{{ acme.certbot_config_dir }}/renewal-hooks/post/50-nas:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash
      exec systemctl reload-or-restart \
        {{ ' '.join(new_cert_reload_services | sort | unique) }}
  - require:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post exists
  - require_in:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post is clean

{{ nftables.config_dir }}/50-nas.conf:
  file.managed:
  - contents: |
      add rule inet filter input \
        tcp dport { {{ open_tcp_ports | sort | map('string') | join(', ') }} } \
        accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
