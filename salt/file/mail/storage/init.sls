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
{% from 'mail/dovecot/map.jinja' import dovecot %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'stunnel/map.jinja' import stunnel %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- acme
- crypto.x509
- mail.dovecot
- network.firewall
- stunnel
- virtual_machine.guest


mail_storage_pkgs:
  pkg.installed:
  - pkgs: {{ salt.grains.filter_by({
        'Debian': (
            'dovecot-imapd',
            'dovecot-lmtpd',
        ),
    }) | json }}


vmail_user:
  group.present:
  - name: vmail
  - system: true
  user.present:
  - name: vmail
  - gid: vmail
  - home: {{ common.nonexistent_path }}
  - createhome: false
  - shell: {{ common.nologin_shell }}
  - system: true
  - require:
    - group: vmail_user

/var/local/mail/persistent/mail:
  file.directory:
  - user: vmail
  - group: vmail
  - dir_mode: 0700
  - require:
    - /var/local/mail/persistent is mounted
    - /var/local/mail/persistent is backed up
    - vmail_user


{% set certificates = {} %}
{{ x509.certificates(
    certificates_in=pillar.mail.storage.certificates,
    warning_on_boilerplate_cert_change=(
        'Update salt/pillar/mail/common.sls with new certificate.'),
    certificates_out=certificates) }}
{% set system_certificate = certificates[pillar.mail.common.storage.name] %}


{{ dovecot.config_dir }}/50-mail-storage.conf:
  file.managed:
  - source: salt://mail/storage/dovecot.conf.jinja
  - template: jinja
  - defaults:
      certificates: {{ certificates | json }}
      default_certificate: {{ certificates.values() | first | json }}
  - require:
    - {{ dovecot.config_dir }} exists
    - mail_storage_pkgs
    - vmail_user
    - /var/local/mail/persistent/mail
    - stunnel_pkgs
  - require_in:
    - {{ dovecot.config_dir }} is clean
  - watch_in:
    - dovecot_running

# I don't see any way to configure Dovecot to require specific client certs, so
# this uses stunnel instead.
{{ stunnel.config_dir }}/lmtp_client_certs.pem:
  file.managed:
  - contents: {{ pillar.mail.common.inbound.certificates | join('\n') | json }}
  - require:
    - {{ stunnel.config_dir }} exists
  - require_in:
    - {{ stunnel.config_dir }} is clean
{{ stunnel.config_dir }}/lmtp.conf:
  file.managed:
  - contents: |
      {{ stunnel.boilerplate | indent(6) }}
      setuid = {{ stunnel.user }}
      setgid = {{ stunnel.group }}
      [lmtp]
      accept = :::24
      sslVersionMin = {{ crypto.openssl.strict_protocols_min }}
      ciphers = {{ crypto.openssl.ciphers_to_string(
          crypto.openssl.strict_ciphers) }}
      key = {{ system_certificate.key }}
      cert = {{ system_certificate.fullchain }}
      CAfile = {{ stunnel.config_dir }}/lmtp_client_certs.pem
      verifyPeer = yes
      connect = {{ dovecot.base_dir }}/lmtp
  - require:
    - {{ stunnel.config_dir }} exists
    - {{ system_certificate.fullchain }}
    - {{ system_certificate.key }}
    - {{ stunnel.config_dir }}/lmtp_client_certs.pem
  - require_in:
    - {{ stunnel.config_dir }} is clean
lmtp_stunnel_enabled:
  service.enabled:
  - name: {{ stunnel.service_instance('lmtp') }}
lmtp_stunnel_running:
  service.running:
  - name: {{ stunnel.service_instance('lmtp') }}
  - watch:
    - {{ stunnel.config_dir }}/lmtp_client_certs.pem
    - {{ stunnel.config_dir }}/lmtp.conf


{{ nftables.config_dir }}/50-mail-storage.conf:
  file.managed:
  - contents: |
      add rule inet filter input tcp dport { 24, imaps } accept
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir
  - onchanges_in:
    - warn about firewall changes
