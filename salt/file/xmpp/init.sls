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
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'xmpp/map.jinja' import xmpp %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- acme
- backup.dump
- network.firewall
- virtual_machine.guest


xmpp_pkgs:
  pkg.installed:
  - pkgs: {{ xmpp.pkgs | json }}


/srv/ejabberd/mod_log_chat:
  file.directory:
  - user: {{ xmpp.ejabberd_user }}
  - group: {{ xmpp.ejabberd_group }}
  - mode: 0700
  - require:
    - /srv/ejabberd is mounted
    - /srv/ejabberd is backed up
    - xmpp_pkgs

/srv/ejabberd/mod_muc_log:
  file.directory:
  - user: {{ xmpp.ejabberd_user }}
  - group: {{ xmpp.ejabberd_group }}
  - mode: 0700
  - require:
    - /srv/ejabberd is mounted
    - /srv/ejabberd is backed up
    - xmpp_pkgs

{{ nftables.config_dir }}/50-ejabberd.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport { 5222, 5223, 5269, 5270 } accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir

{% for domain in pillar.xmpp.domains %}
{{ acme_cert(domain, group=xmpp.ejabberd_group) }}
{{ acme_cert('conference.' + domain, group=xmpp.ejabberd_group) }}
{% endfor %}

{{ acme.certbot_config_dir }}/renewal-hooks/post/50-xmpp:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash
      exec systemctl reload ejabberd.service
  - require:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post exists
    - xmpp_pkgs
  - require_in:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post is clean

{{ xmpp.ejabberd_config_file }}:
  file.managed:
  - source: salt://xmpp/ejabberd.yml.jinja
  - template: jinja
  - require:
    - xmpp_pkgs
    {% for domain in pillar.xmpp.domains %}
    - {{ acme.certbot_config_dir }}/live/{{ domain }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ domain }}/privkey.pem
    - {{ acme.certbot_config_dir }}/live/conference.{{ domain }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/conference.{{ domain }}/privkey.pem
    {% endfor %}
    - /srv/ejabberd/mod_log_chat
    - /srv/ejabberd/mod_muc_log

ejabberd_enabled:
  service.enabled:
  - name: ejabberd.service

ejabberd_running:
  service.running:
  - name: ejabberd.service
  - watch:
    - {{ xmpp.ejabberd_config_file }}

{{ common.local_lib }}/backup/dump/sources/ejabberd:
  file.managed:
  - source: salt://xmpp/dump.py
  - mode: 0755
  - require:
    - {{ common.local_lib }}/backup/dump/sources exists
    - {{ common.local_lib }}/backup/dump/sources/ejabberd is dumped
    - xmpp_pkgs
  - require_in:
    - {{ common.local_lib }}/backup/dump/sources is clean

# https://github.com/processone/ejabberd/blob/655dcbcb7467db3cb0f89cf99d34cc2244e6c84f/src/mod_mam.erl#L98-L103
# http://erlang.org/faq/mnesia.html#idp32901264
{% set _du = 'du --apparent-size --human-readable --summarize' %}
{{ _du }} --threshold=768M {{ xmpp.ejabberd_data_dir }}:
  cron.present:
  - identifier: 51226146-e8b8-4e73-8a8e-ecdf09f95185
  - minute: random
  - hour: random
  - dayweek: random
{{ _du }} --threshold=1G {{ xmpp.ejabberd_data_dir }}:
  cron.present:
  - identifier: 6ae7a5b7-6a2b-4ce2-8979-30e5c825e6f3
  - minute: random
  - hour: random
