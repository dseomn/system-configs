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


{% from 'crypto/map.jinja' import crypto %}
{% from 'crypto/x509/map.jinja' import x509 %}
{% from 'mail/map.jinja' import mail %}
{% from 'network/firewall/map.jinja' import nftables %}


{% set postfix_instance = 'postfix-inbound' %}
{% set postfix_config_dir = mail.postfix_config_dir(postfix_instance) %}


include:
- acme
- crypto
- crypto.x509
- mail
- network.firewall


{{ mail.postfix_instance(postfix_instance) }}


{% set certificates = {} %}
{{ x509.certificates(
    certificates_in=pillar.mail.inbound.certificates,
    warning_on_boilerplate_cert_change=(
        'Update salt/pillar/mail/common.sls with new fingerprint.'),
    certificates_out=certificates) }}


{{ postfix_config_dir }}/mail_outbound_client_certs:
  file.managed:
  - contents: {{
        mail.postmap_contents(
            pillar.mail.common.outbound[
                'cert_fingerprints_' + crypto.openssl.digest]) | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('mail_outbound_client_certs', instance=postfix_instance) }}

{{ postfix_config_dir }}/master.cf:
  file.blockreplace:
  - marker_start: '# START: mail.inbound'
  - marker_end: '# END: mail.inbound'
  - content: |
      submissions inet n - y - - smtpd
        -o syslog_name={{ postfix_instance }}/${service_name}
        -o smtpd_tls_wrappermode=yes
        -o smtpd_tls_ask_ccert=yes
        -o relay_clientcerts=${_database_dir}/mail_outbound_client_certs
        -o { smtpd_client_restrictions = permit_tls_clientcerts defer }
  - append_if_not_found: true
  - require:
    - {{ postfix_instance }}
  - watch_in:
    - postfix_running

{{ mail.postfix_certificates(
    certificates=certificates, instance=postfix_instance) }}

{{ postfix_config_dir }}/virtual_mailbox_domains:
  file.managed:
  - mode: 0600
  - contents: {{ mail.postmap_contents(pillar.mail.recipient_domains) | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('virtual_mailbox_domains', instance=postfix_instance) }}

{{ postfix_config_dir }}/virtual_mailbox:
  file.managed:
  - mode: 0600
  - contents: {{ mail.postmap_contents(pillar.mail.mailbox_addresses) | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('virtual_mailbox', instance=postfix_instance) }}

{{ postfix_config_dir }}/virtual_alias:
  file.managed:
  - mode: 0600
  - contents: {{ mail.postmap_contents(pillar.mail.aliases) | json }}
  - require:
    - {{ postfix_instance }}
{{ mail.postmap('virtual_alias', instance=postfix_instance) }}

{{ postfix_config_dir }}/main.cf:
  file.managed:
  - source: salt://mail/inbound/main.cf.jinja
  - template: jinja
  - defaults:
      default_certificate: {{ certificates.values() | first | json }}
  - require:
    - {{ postfix_instance }}
    - {{ postfix_config_dir }}/tls_server_sni
    - {{ postfix_config_dir }}/virtual_mailbox_domains
    - {{ postfix_config_dir }}/virtual_mailbox
    - {{ postfix_config_dir }}/virtual_alias
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
