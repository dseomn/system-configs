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
{% from 'crypto/x509/map.jinja' import x509 %}
{% from 'mail/dkimpy_milter/map.jinja' import dkimpy_milter %}
{% from 'mail/dovecot/map.jinja' import dovecot %}
{% from 'mail/map.jinja' import mail %}
{% from 'network/firewall/map.jinja' import nftables %}


{% set postfix_instance = 'postfix-outbound' %}
{% set postfix_config_dir = mail.postfix_config_dir(postfix_instance) %}
{% set postfix_queue_dir = mail.postfix_queue_dir(postfix_instance) %}


include:
- acme
- crypto
- crypto.secret_rotation
- crypto.x509
- mail
- mail.dkimpy_milter
- mail.dovecot
- network.firewall


{{ mail.postfix_instance(postfix_instance) }}


{% set certificates = {} %}
{{ x509.certificates(
    certificates_in=pillar.mail.outbound.certificates,
    warning_on_boilerplate_cert_change=(
        'Update salt/pillar/mail/common.sls with new fingerprint.'),
    certificates_out=certificates) }}


{{ postfix_queue_dir }}/dkimpy-milter:
  file.directory:
  - user: {{ dkimpy_milter.user }}
  - group: {{ dkimpy_milter.group }}
  - dir_mode: 0750
  - require:
    - {{ postfix_instance }}

{{ dkimpy_milter.config_dir }}/domain:
  file.managed:
  - contents: |
      {%- for domain in pillar.mail.authoritative_non_sub_domains %}
      {{ domain }}
      {%- endfor %}
  - require:
    - {{ dkimpy_milter.config_dir }} exists
  - require_in:
    - {{ dkimpy_milter.config_dir }} is clean
  - watch_in:
    - dkimpy_milter_running

{% for key_type in ('rsa', 'ed25519') %}
{% for selector in pillar.mail.outbound.dkim_selectors[key_type] %}
dkim key {{ selector }}:
  cmd.run:
  - name: >-
      dknewkey
      --ktype={{ key_type }}
      {{ dkimpy_milter.config_dir }}/{{ selector }}
      &&
      printf '%s' "$SHOW_RECORD_SCRIPT" |
        python3 - {{ dkimpy_milter.config_dir }}/{{ selector }}.dns
  - env:
    - SHOW_RECORD_SCRIPT: |
        import sys
        with open(sys.argv[1], mode='rt') as record_file:
          record = record_file.read()
        original_tags = {}
        for tag_spec in record.split(';'):
          tag_name, _, tag_value = tag_spec.partition('=')
          original_tags[tag_name.strip()] = tag_value.strip()
        # https://www.iana.org/assignments/dkim-parameters/dkim-parameters.xhtml#dkim-parameters-5
        # https://www.iana.org/assignments/dkim-parameters/dkim-parameters.xhtml#dkim-parameters-9
        tags = {
            'v': original_tags.pop('v'),
            'h': original_tags.pop('h', None),
            'k': original_tags.pop('k'),
            'p': original_tags.pop('p'),
            's': 'email',
        }
        if original_tags:
          raise ValueError(original_tags)
        print(
            '; '.join(
                f'{tag_name}={tag_value}'
                for tag_name, tag_value in tags.items()
                if tag_value is not None))
  - creates:
    - {{ dkimpy_milter.config_dir }}/{{ selector }}.key
    - {{ dkimpy_milter.config_dir }}/{{ selector }}.dns
  - require:
    - {{ dkimpy_milter.config_dir }} exists
  test.configurable_test_state:
  - warnings: >-
      Add
      {%- for domain in pillar.mail.authoritative_non_sub_domains %}
      {{ selector }}._domainkey.{{ domain }}.
      {%- endfor %}
      TXT record(s), and remove any old DKIM records.
  - onchanges:
    - cmd: dkim key {{ selector }}
{{ dkimpy_milter.config_dir }}/{{ selector }}.key:
  file.exists:
  - require:
    - dkim key {{ selector }}
  - require_in:
    - {{ dkimpy_milter.config_dir }} is clean
{{ dkimpy_milter.config_dir }}/{{ selector }}.dns:
  file.exists:
  - require:
    - dkim key {{ selector }}
  - require_in:
    - {{ dkimpy_milter.config_dir }} is clean
{% endfor %}
{% endfor %}
{% set dkim_key_rsa =
    dkimpy_milter.config_dir + '/' +
    pillar.mail.outbound.dkim_selectors.active.rsa + '.key' %}
{% set dkim_key_ed25519 =
    dkimpy_milter.config_dir + '/' +
    pillar.mail.outbound.dkim_selectors.active.ed25519 + '.key' %}
active dkim keys should be rotated:
  file.accumulated:
  - name: active dkim keys
  - filename: {{ common.local_sbin }}/monitor-secret-age
  - text:
    - {{ dkim_key_rsa }}
    - {{ dkim_key_ed25519 }}
  - require:
    - {{ dkim_key_rsa }}
    - {{ dkim_key_ed25519 }}
  - require_in:
    - file: {{ common.local_sbin }}/monitor-secret-age

{{ dkimpy_milter.config_file }}:
  file.managed:
  - contents: |
      {{ dkimpy_milter.conf_boilerplate() | indent(6) }}
      Socket local:{{ postfix_queue_dir }}/dkimpy-milter/sign
      Mode s
      Domain file:{{ dkimpy_milter.config_dir }}/domain
      SubDomains yes
      InternalHosts csl:
      Canonicalization relaxed/simple
      Selector {{ pillar.mail.outbound.dkim_selectors.active.rsa }}
      KeyFile {{ dkim_key_rsa }}
      SelectorEd25519 {{ pillar.mail.outbound.dkim_selectors.active.ed25519 }}
      KeyFileEd25519 {{ dkim_key_ed25519 }}
  - require:
    - {{ dkimpy_milter.config_dir }} exists
    - {{ postfix_queue_dir }}/dkimpy-milter
    - {{ dkimpy_milter.config_dir }}/domain
    - {{ dkim_key_rsa }}
    - {{ dkim_key_ed25519 }}
  - require_in:
    - {{ dkimpy_milter.config_dir }} is clean
  - watch_in:
    - dkimpy_milter_running


{{ postfix_config_dir }}/master.cf:
  file.blockreplace:
  - marker_start: '# START: mail.outbound'
  - marker_end: '# END: mail.outbound'
  - content: |
      submissions inet n - y - - smtpd
        -o syslog_name={{ postfix_instance }}/${service_name}
        -o smtpd_tls_wrappermode=yes
      {%- for transport_name, transport
          in pillar.mail.outbound.get('transports', {}).items() %}
      {{ transport_name }} unix - - y - - smtp
        -o syslog_name={{ postfix_instance }}/${service_name}
        {%- if 'default_port' in transport %}
        -o smtp_tcp_port={{ transport.default_port }}
        {%- endif %}
        {%- if transport.get('implicit_tls', False) %}
        -o smtp_tls_wrappermode=yes
        {%- endif %}
        {%- if 'certificate' in transport %}
        {%- set certificate = certificates[transport.certificate] %}
        -o { smtp_tls_chain_files =
          {{ certificate.key }}
          {{ certificate.fullchain }} }
        {%- endif %}
      {%- endfor %}
  - append_if_not_found: true
  - require:
    - {{ postfix_instance }}
  - watch_in:
    - postfix_running

{{ mail.postfix_certificates(
    certificates=certificates, instance=postfix_instance) }}

{{ dovecot.config_dir }}/50-{{ postfix_instance }}.conf:
  file.managed:
  - contents: |
      service auth {
        unix_listener {{ postfix_queue_dir }}/private/auth {
          mode = 0660
          user = {{ mail.postfix_user }}
          group = {{ mail.postfix_group }}
        }
      }
  - require:
    - {{ dovecot.config_dir }} exists
    - {{ postfix_instance }}
  - require_in:
    - {{ dovecot.config_dir }} is clean
  - watch_in:
    - dovecot_running

{{ postfix_config_dir }}/smtpd_sender_login:
  file.managed:
  - mode: 0600
  - contents: |
      {%- for account_name, logins in pillar.mail.logins_by_account.items() %}
      {{ account_name }} {{ logins | join(' ') }}
      {%- endfor %}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('smtpd_sender_login', instance=postfix_instance) }}

{{ postfix_config_dir }}/smtpd_relay_restrictions_sasl:
  file.managed:
  - mode: 0600
  - contents: |
      {%- for account_name, logins in pillar.mail.logins_by_account.items() %}
        {%- set account_recipients =
            pillar.mail.accounts[account_name].recipients %}
        {%- if account_recipients == 'all' %}
          {%- set account_access = 'permit' %}
        {%- elif account_recipients == 'local' %}
          {%- set account_access = 'reject_unauth_destination permit' %}
        {%- else %}
          {%- do {}['invalid "recipients" value for ' + account_name] %}
        {%- endif %}
      {%- for login_name in logins %}
      {{ login_name }} {{ account_access }}
      {%- endfor %}
      {%- endfor %}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('smtpd_relay_restrictions_sasl', instance=postfix_instance) }}

{{ postfix_config_dir }}/relay_domains:
  file.managed:
  - mode: 0600
  # Use authoritative_domains instead of recipient_domains here so that bounces
  # to non-recipient senders get bounced again instead of getting forwarded
  # upstream. This does allow probing of non-recipient authoritative domains,
  # but only by authenticated clients.
  - contents: {{
        mail.postmap_contents(pillar.mail.authoritative_domains) | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('relay_domains', instance=postfix_instance) }}

{{ postfix_config_dir }}/relay_recipient:
  file.managed:
  - mode: 0600
  - contents: {{
        mail.postmap_contents(pillar.mail.recipient_addresses) | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('relay_recipient', instance=postfix_instance) }}

{{ postfix_config_dir }}/smtp_sasl_password:
  file.managed:
  - mode: 0600
  - contents: {{
        mail.postmap_contents(pillar.mail.outbound.get('passwords', {}))
        | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('smtp_sasl_password', instance=postfix_instance) }}

{{ postfix_config_dir }}/main.cf:
  file.managed:
  - source: salt://mail/outbound/main.cf.jinja
  - template: jinja
  - defaults:
      default_certificate: {{ certificates.values() | first | json }}
  - require:
    - {{ postfix_instance }}
    - {{ postfix_config_dir }}/tls_server_sni
    - {{ postfix_config_dir }}/smtpd_sender_login
    - {{ postfix_config_dir }}/smtpd_relay_restrictions_sasl
    - {{ postfix_config_dir }}/relay_domains
    - {{ postfix_config_dir }}/relay_recipient
    - crypto_pkgs
    - {{ postfix_config_dir }}/smtp_sasl_password
  - watch_in:
    - postfix_running


{{ nftables.config_dir }}/50-mail-outbound.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport submissions accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
