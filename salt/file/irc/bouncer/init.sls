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
{% from 'irc/bouncer/map.jinja' import irc_bouncer %}
{% from 'network/firewall/map.jinja' import nftables %}


# https://github.com/znc/znc/blob/e0ffdddd473e97cb843f2bc8ad4fa16cf47c65b4/src/ZNCString.cpp#L1508
# Note that this supports only ascii.
{% macro znc_escape(string) -%}
  {%- for char in string -%}
    {%- if char.isalnum() -%}
      {{- char -}}
    {%- else -%}
      %{{- char.encode().hex() -}};
    {%- endif -%}
  {%- endfor -%}
{%- endmacro %}


{% macro znc_registry(config) -%}
{% for key, value in config.items() -%}
{{ znc_escape(key) }} {{ znc_escape(value) }}
{% endfor -%}
{% endmacro %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- acme
- network.firewall
- virtual_machine.guest


irc_bouncer_pkgs:
  pkg.installed:
  - pkgs: {{ irc_bouncer.pkgs | json }}
  - require:
    - /var/lib/znc is mounted


znc_files:
  test.nop:
  - require:
    - /var/lib/znc is mounted
    - /var/lib/znc is backed up

/etc/znc:
  file.directory:
  - group: {{ irc_bouncer.znc_group }}
  - mode: 0750
  - require:
    - irc_bouncer_pkgs
  - require_in:
    - znc_files

{{ acme_cert(pillar.irc.bouncer.name, group=irc_bouncer.znc_group) }}

{{ acme.certbot_config_dir }}/renewal-hooks/post/50-irc-bouncer:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash
      exec systemctl restart {{ irc_bouncer.znc_service }}
  - require:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post exists
  - require_in:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post is clean

{{ nftables.config_dir }}/50-znc.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport 6697 accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir

/etc/znc/configs/znc.conf:
  file.managed:
  - group: {{ irc_bouncer.znc_group }}
  - mode: 0640
  - makedirs: true
  - contents: |
      LoadModule = adminlog
      LoadModule = log
      SSLCertFile = {{ acme.certbot_config_dir }}/live/{{ pillar.irc.bouncer.name }}/fullchain.pem
      SSLCiphers = {{ crypto.openssl.ciphers_to_string(
          crypto.openssl.general_ciphers) }}
      SSLKeyFile = {{ acme.certbot_config_dir }}/live/{{ pillar.irc.bouncer.name }}/privkey.pem
      SSLProtocols = {{ crypto.openssl.protocols_disabled_to_string(
          crypto.openssl.general_protocols_disabled) }}
      Version = 1.8.2
      <Listener ircs-u>
        AllowIRC = true
        AllowWeb = false
        IPv4 = true
        IPv6 = true
        Port = 6697
        SSL = true
      </Listener>
      {% for username, user in pillar.irc.bouncer.znc.users.items() %}
      <User {{ username }}>
        Admin = false
        AltNick = {{ username }}_
        Ident = {{ username }}
        Nick = {{ username }}
        RealName = {{ user.real_name }}
        {% for network_name, network in user.networks.items() %}
        <Network {{ network_name }}>
          IRCConnectEnabled = true
          LoadModule = keepnick
          LoadModule = sasl
          LoadModule = stickychan {{ ','.join(network.channels) }}
          Server = {{ network.server }}
          TrustAllCerts = false
          TrustPKI = true
          {% for channel in network.channels %}
          <Chan {{ channel }}>
          </Chan>
          {% endfor %}
        </Network>
        {% endfor %}
        {{ user.pass_section | indent(8) }}
      </User>
      {% endfor %}
  - require:
    - /etc/znc
    - {{ acme.certbot_config_dir }}/live/{{ pillar.irc.bouncer.name }}/fullchain.pem
    - {{ acme.certbot_config_dir }}/live/{{ pillar.irc.bouncer.name }}/privkey.pem
  - require_in:
    - znc_files

{% for username, user in pillar.irc.bouncer.znc.users.items() %}
{% for network_name, network in user.networks.items() %}
/etc/znc/users/{{ username }}/networks/{{ network_name }}/moddata/sasl/.registry:
  file.managed:
  - group: {{ irc_bouncer.znc_group }}
  - mode: 0640
  - makedirs: true
  - contents:  {{ znc_registry({
        'mechanisms': 'PLAIN',
        'password': network.password,
        'require_auth': 'yes',
        'username': username,
    }) | json }}
  - require:
    - /etc/znc
  - require_in:
    - znc_files
{% endfor %}
{% endfor %}

/var/lib/znc has correct permissions:
  file.directory:
  - name: /var/lib/znc
  - user: {{ irc_bouncer.znc_user }}
  - group: {{ irc_bouncer.znc_group }}
  - mode: 0700
  - require:
    - /var/lib/znc is mounted
    - irc_bouncer_pkgs
  - require_in:
    - znc_files

{% for mutable_dir in irc_bouncer.znc_mutable.global_dirs %}
/var/lib/znc/{{ mutable_dir }}:
  file.directory:
  - user: {{ irc_bouncer.znc_user }}
  - group: {{ irc_bouncer.znc_group }}
  - mode: 0700
  - makedirs: true
  - require:
    - /var/lib/znc has correct permissions
  - require_in:
    - znc_files
{% endfor %}

{% for mutable_file in irc_bouncer.znc_mutable.global_files %}
/var/lib/znc/{{ '/'.join(mutable_file.split('/')[:-1]) }}:
  file.directory:
  - user: {{ irc_bouncer.znc_user }}
  - group: {{ irc_bouncer.znc_group }}
  - mode: 0700
  - makedirs: true
  - require:
    - /var/lib/znc has correct permissions
  - require_in:
    - znc_files
{% endfor %}

{{ common.local_bin }}/znc-wrapper:
  file.managed:
  - source: salt://irc/bouncer/znc_wrapper.py.jinja
  - mode: 0755
  - template: jinja
  - require:
    - irc_bouncer_pkgs
    - znc_files

/etc/systemd/system/{{ irc_bouncer.znc_service }}.d/50-salt-irc-bouncer.conf:
  file.managed:
  - makedirs: true
  - contents: |
      [Service]
      ExecStart=
      ExecStart={{ common.local_bin }}/znc-wrapper --foreground
  - require:
    - {{ common.local_bin }}/znc-wrapper

znc_unit_reload:
  cmd.run:
  - name: systemctl daemon-reload
  - onchanges:
    - /etc/systemd/system/{{ irc_bouncer.znc_service }}.d/50-salt-irc-bouncer.conf

znc_enabled:
  service.enabled:
  - name: {{ irc_bouncer.znc_service }}

znc_running:
  service.running:
  - name: {{ irc_bouncer.znc_service }}
  - watch:
    - /etc/znc/configs/znc.conf
    - {{ common.local_bin }}/znc-wrapper
    - znc_unit_reload
