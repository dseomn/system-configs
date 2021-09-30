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
{% from 'crypto/x509/map.jinja' import x509 %}
{% from 'mail/dovecot/map.jinja' import dovecot %}
{% from 'mail/map.jinja' import mail %}
{% from 'network/firewall/map.jinja' import nftables %}


{% set postfix_instance = 'postfix-outbound' %}
{% set postfix_config_dir = mail.postfix_config_dir(postfix_instance) %}
{% set postfix_queue_dir = mail.postfix_queue_dir(postfix_instance) %}


include:
- acme
- crypto
- crypto.x509
- mail
- mail.dovecot
- network.firewall


{{ mail.postfix_instance(postfix_instance) }}


{% set certificates = {} %}
{% for certificate_name, certificate in
    pillar.mail.outbound.certificates.items() %}
{% if certificate.type == 'general' %}
{{ acme_cert(certificate_name) }}
{% do certificates.update({
    certificate_name: {
        'key':
            acme.certbot_config_dir + '/live/' + certificate_name +
            '/privkey.pem',
        'fullchain':
            acme.certbot_config_dir + '/live/' + certificate_name +
            '/fullchain.pem',
        'onchanges': ('acme_cert_' + certificate_name,),
    }
}) %}
{% elif certificate.type == 'strict' %}
{{ x509.boilerplate_certificate(
    certificate_name,
    warning_on_change=(
        'Update salt/pillar/mail/local_relay.sls with new fingerprint.'),
) }}
{% do certificates.update({
    certificate_name: {
        'key': common.local_etc + '/x509/' + certificate_name + '/privkey.pem',
        'fullchain':
            common.local_etc + '/x509/' + certificate_name + '/cert.pem',
        'onchanges': ('boilerplate_certificate_' + certificate_name,),
    }
}) %}
{% else %}
{{ {}['error: unknown certificate type: ' + certificate.type] }}
{% endif %}
{% endfor %}

restart postfix on changes to certificates:
  test.succeed_with_changes:
  - onchanges:
    {% for certificate in certificates.values() %}
    {% for onchanges in certificate.onchanges %}
    - {{ onchanges }}
    {% endfor %}
    {% endfor %}
  - watch_in:
    - postfix_running


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

{% set tls_server_sni_files = [] %}
{% set tls_server_sni_onchanges_extra = [] %}
{{ postfix_config_dir }}/tls_server_sni:
  file.managed:
  # Even though the contents of this file aren't sensitive, it looks like
  # postmap copies the permissions to the database file, and that file contains
  # the private keys pointed to here.
  - mode: 0600
  - contents: |
      {%- for certificate_name, certificate in certificates.items() %}
      {%- do tls_server_sni_files.extend(
          (certificate.key, certificate.fullchain)) %}
      {%- do tls_server_sni_onchanges_extra.extend(certificate.onchanges) %}
      {{ certificate_name }} {{ certificate.key }} {{ certificate.fullchain }}
      {%- endfor %}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap(
    'tls_server_sni',
    instance=postfix_instance,
    files=tls_server_sni_files,
    onchanges_extra=tls_server_sni_onchanges_extra,
) }}

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


{{ acme.certbot_config_dir }}/renewal-hooks/post/50-mail-outbound:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash -e
      postmap -F -c {{ postfix_config_dir }} \
        {{ postfix_config_dir }}/tls_server_sni
      systemctl reload-or-restart {{ mail.postfix_service }}
  - require:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post exists
    - mail_pkgs
    - {{ postfix_config_dir }}/tls_server_sni
  - require_in:
    - {{ acme.certbot_config_dir }}/renewal-hooks/post is clean


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
