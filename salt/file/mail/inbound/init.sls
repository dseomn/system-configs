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
{% from 'crypto/map.jinja' import crypto %}
{% from 'crypto/x509/map.jinja' import x509 %}
{% from 'mail/dkimpy_milter/map.jinja' import dkimpy_milter %}
{% from 'mail/inbound/map.jinja' import mail_inbound %}
{% from 'mail/map.jinja' import mail %}
{% from 'network/firewall/map.jinja' import nftables %}


{% set postfix_instance = 'postfix-inbound' %}
{% set postfix_config_dir = mail.postfix_config_dir(postfix_instance) %}
{% set postfix_queue_dir = mail.postfix_queue_dir(postfix_instance) %}


include:
- acme
- common
- crypto
- crypto.x509
- mail
- mail.dkimpy_milter
- network.firewall


mail_inbound_pkgs:
  pkg.installed:
  - pkgs: {{ mail_inbound.pkgs | tojson }}
  - require_in:
    - users and groups are done


{{ mail.postfix_instance(postfix_instance) }}


{% set certificates = {} %}
{{ x509.certificates(
    certificates_in=pillar.mail.inbound.certificates,
    warning_on_boilerplate_cert_change=(
        'Update salt/pillar/mail/common.sls with new certificate.'),
    certificates_out=certificates) }}
{% set system_certificate = certificates[pillar.mail.common.inbound.name] %}


{{ postfix_queue_dir }}/dkimpy-milter:
  file.directory:
  - user: {{ dkimpy_milter.user }}
  - group: {{ dkimpy_milter.group }}
  - dir_mode: 0750
  - require:
    - {{ postfix_instance }}

{{ dkimpy_milter.config_file }}:
  file.managed:
  - contents: |
      {{ dkimpy_milter.conf_boilerplate() | indent(6) }}
      Socket local:{{ postfix_queue_dir }}/dkimpy-milter/verify
      Mode v
      Domain csl:
      InternalHosts csl:
      AuthservID {{ grains.id }}
  - require:
    - {{ dkimpy_milter.config_dir }} exists
    - {{ postfix_queue_dir }}/dkimpy-milter
  - require_in:
    - {{ dkimpy_milter.config_dir }} is clean
  - watch_in:
    - dkimpy_milter_running


opendmarc_enabled:
  service.enabled:
  - name: {{ mail_inbound.opendmarc_service }}
  - require:
    - mail_inbound_pkgs

opendmarc_running:
  service.running:
  - name: {{ mail_inbound.opendmarc_service }}
  - require:
    - mail_inbound_pkgs

# Let postfix connect to opendmarc's unix socket.
{{ common.user_in_group(
    user=mail.postfix_user,
    group=mail_inbound.opendmarc_group,
    require=('mail_pkgs', 'mail_inbound_pkgs'),
    watch_in=('postfix_running',),
) }}

{{ postfix_queue_dir }}/opendmarc:
  file.directory:
  - user: {{ mail_inbound.opendmarc_user }}
  - group: {{ mail_inbound.opendmarc_group }}
  - dir_mode: 0750
  - require:
    - {{ postfix_instance }}

{{ mail_inbound.opendmarc_config_file }}.orig:
  file.copy:
  - source: {{ mail_inbound.opendmarc_config_file }}
  - require:
    - mail_inbound_pkgs
{{ mail_inbound.opendmarc_config_file }}:
  file.managed:
  - source: salt://mail/inbound/opendmarc.conf.jinja
  - template: jinja
  - require:
    - {{ mail_inbound.opendmarc_config_file }}.orig
    - {{ postfix_queue_dir }}/opendmarc
  - watch_in:
    - opendmarc_running


{% set mail_outbound_fingerprints = [] %}
{% for certificate in pillar.mail.common.outbound.certificates %}
  {% do mail_outbound_fingerprints.append(
      crypto.openssl.cert_fingerprint(certificate)) %}
{% endfor %}
{{ postfix_config_dir }}/mail_outbound_client_certs:
  file.managed:
  - contents: {{ mail.postmap_contents(mail_outbound_fingerprints) | tojson }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('mail_outbound_client_certs', instance=postfix_instance) }}

{{ postfix_config_dir }}/master.cf mail.inbound:
  file.blockreplace:
  - name: {{ postfix_config_dir }}/master.cf
  - marker_start: '# START: mail.inbound :#'
  - marker_end: '# END: mail.inbound :#'
  - content: |
      submissions inet n - y - - smtpd
        -o syslog_name={{ postfix_instance }}/${service_name}
        -o smtpd_tls_wrappermode=yes
        -o smtpd_tls_ask_ccert=yes
        -o relay_clientcerts=${_database_dir}/mail_outbound_client_certs
        -o { smtpd_client_restrictions = permit_tls_clientcerts defer }
        -o _admd_internal=yes
  - append_if_not_found: true
  - require:
    - {{ postfix_instance }}
  - watch_in:
    - postfix_running
{{ postfix_config_dir }}/master.cf mail.inbound lmtp:
  file.blockreplace:
  - name: {{ postfix_config_dir }}/master.cf
  - marker_start: '# START: mail.inbound lmtp :#'
  - marker_end: '# END: mail.inbound lmtp :#'
  - content: '  flags=DORX'
  - insert_after_match: '^\s*lmtp\s+unix\s+(\S+\s+){5}lmtp\b'
  - require:
    - {{ postfix_instance }}
  - watch_in:
    - postfix_running

{{ mail.postfix_certificates(
    certificates=certificates, instance=postfix_instance) }}

{{ postfix_config_dir }}/virtual_mailbox_domains:
  file.managed:
  - mode: 0600
  - contents: {{
        mail.postmap_contents(pillar.mail.recipient_domains) | tojson }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('virtual_mailbox_domains', instance=postfix_instance) }}

{{ postfix_config_dir }}/virtual_mailbox:
  file.managed:
  - mode: 0600
  - contents: {{
        mail.postmap_contents(pillar.mail.mailbox_addresses) | tojson }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('virtual_mailbox', instance=postfix_instance) }}

{{ postfix_config_dir }}/virtual_alias:
  file.managed:
  - mode: 0600
  - contents: {{ mail.postmap_contents(pillar.mail.aliases) | tojson }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('virtual_alias', instance=postfix_instance) }}

{{ postfix_config_dir }}/main.cf:
  file.managed:
  - source: salt://mail/inbound/main.cf.jinja
  - template: jinja
  - defaults:
      default_certificate: {{ certificates.values() | first | tojson }}
      system_certificate: {{ system_certificate | tojson }}
  - require:
    - {{ postfix_instance }}
    - {{ postfix_config_dir }}/tls_server_sni
    - {{ postfix_config_dir }}/virtual_mailbox_domains
    - {{ postfix_config_dir }}/virtual_mailbox
    - {{ postfix_config_dir }}/virtual_alias
    - {{ system_certificate.key }}
    - {{ system_certificate.fullchain }}
    - crypto_pkgs
  - watch_in:
    - postfix_running


{{ nftables.config_dir }}/50-mail-inbound.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport { smtp, submissions } accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
