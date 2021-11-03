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
{% from 'mail/storage/map.jinja' import mail_storage %}
{% from 'network/firewall/map.jinja' import nftables %}
{% from 'stunnel/map.jinja' import stunnel %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- acme
- common
- crypto.x509
- mail.dovecot
- network.firewall
- stunnel
- virtual_machine.guest


mail_storage_pkgs:
  pkg.installed:
  - pkgs: {{ mail_storage.pkgs | tojson }}


{{ common.system_user_and_group('vmail') }}

/var/local/mail/persistent/mail:
  file.directory:
  - user: vmail
  - group: vmail
  - dir_mode: 0700
  - require:
    - /var/local/mail/persistent is mounted
    - /var/local/mail/persistent is backed up
    - vmail user and group

/var/local/mail/spamassassin:
  file.directory:
  - user: vmail
  - group: vmail
  - dir_mode: 0700
  - makedirs: true

{{ common.local_etc }}/mail exists:
  file.directory:
  - name: {{ common.local_etc }}/mail
  - user: root
  - group: vmail
  - dir_mode: 0750
{{ common.local_etc }}/mail is clean:
  file.directory:
  - name: {{ common.local_etc }}/mail
  - user: root
  - group: vmail
  - dir_mode: 0750
  - file_mode: 0640
  - recurse:
    - user
    - group
    - mode
  - clean: true
  - require:
    - {{ common.local_etc }}/mail exists

/var/cache/mail:
  file.directory:
  - user: vmail
  - group: vmail
  - dir_mode: 0700


{% set certificates = {} %}
{{ x509.certificates(
    certificates_in=pillar.mail.storage.certificates,
    warning_on_boilerplate_cert_change=(
        'Update salt/pillar/mail/common.sls with new certificate.'),
    certificates_out=certificates) }}
{% set system_certificate = certificates[pillar.mail.common.storage.name] %}


spamd_enabled:
  service.enabled:
  - name: {{ mail_storage.spamd_service }}
spamd_running:
  service.running:
  - name: {{ mail_storage.spamd_service }}

{{ mail_storage.spamassassin_config_file }}:
  file.managed:
  - source: salt://mail/storage/spamassassin.cf.jinja
  - template: jinja
  - require:
    - mail_storage_pkgs
  - watch_in:
    - spamd_running

{{ mail_storage.spamassassin_default_file }}:
  file.blockreplace:
  - marker_start: '# START: mail.storage :#'
  - marker_end: '# END: mail.storage :#'
  - content: |
      OPTIONS="\
        --listen=/var/local/mail/spamassassin/spamd \
        --socketowner=vmail \
        --socketmode=0700 \
        --username=vmail \
        --virtual-config-dir=/var/cache/mail/%d/%l/spamassassin \
        --nouser-config"
      CRON=1
  - append_if_not_found: true
  - require:
    - mail_storage_pkgs
    - /var/local/mail/spamassassin
    - vmail user and group
    - /var/cache/mail
  - watch_in:
    - spamd_running

{{ mail_storage.spamc_config_file }}:
  file.managed:
  - contents: |
      --max-size={{ 1024 * 1024 }}
      --socket=/var/local/mail/spamassassin/spamd
      # The sum of the timeouts should be less than sieve_filter_exec_timeout in
      # dovecot.
      --connect-timeout=300
      --timeout=150
  - require:
    - mail_storage_pkgs
    - /var/local/mail/spamassassin

{{ common.local_lib }}/spam-train:
  file.managed:
  - source: salt://mail/storage/spam_train.py
  - mode: 0755
  - require:
    - mail_storage_pkgs

{% set spam_train_id_prefix = 'f1d84c3f-9ce3-46d3-88f1-90648b58d0c2.' %}
{% set old_spam_train_cron_jobs = {} %}
{% for cron_job in salt.cron.list_tab('vmail').crons
    if cron_job.identifier.startswith(spam_train_id_prefix) %}
  {% do old_spam_train_cron_jobs.update({cron_job.identifier: None}) %}
{% endfor %}
{% for account_name in pillar.mail.accounts %}
{% set account_user, account_domain = account_name.split('@') %}
{% set identifier = spam_train_id_prefix + account_name %}
{% do old_spam_train_cron_jobs.pop(identifier, None) %}
{{ identifier | tojson }}:
  cron.present:
  # `FOO=bar quux` would put the whole line into the process args to `sh -c`. So
  # this command uses standard input to run spam-train without leaking the
  # variables in the process args.
  - name: >-
      sh
      {{- '%' -}}
      USER_DIR=/var/cache/mail/{{ account_domain }}/{{ account_user }}/spamassassin
      MAILDIR=/var/local/mail/persistent/mail/{{ account_domain }}/{{ account_user }}/Maildir
      exec
      {{ common.local_lib }}/spam-train
  - user: vmail
  - identifier: {{ identifier | tojson }}
  - minute: random
  - hour: random
  - require:
    - {{ common.local_lib }}/spam-train
    - /var/cache/mail
    - /var/local/mail/persistent/mail
{% endfor %}
{% for identifier in old_spam_train_cron_jobs %}
{{ identifier | tojson }}:
  cron.absent:
  - user: vmail
  - identifier: {{ identifier | tojson }}
{% endfor %}


{{ dovecot.top_config_dir }}/sieve-filter-bin exists:
  file.directory:
  - name: {{ dovecot.top_config_dir }}/sieve-filter-bin
  - require:
    - dovecot_pkgs
{{ dovecot.top_config_dir }}/sieve-filter-bin is clean:
  file.directory:
  - name: {{ dovecot.top_config_dir }}/sieve-filter-bin
  - clean: true
  - require:
    - {{ dovecot.top_config_dir }}/sieve-filter-bin exists

{{ dovecot.top_config_dir }}/sieve-filter-bin/spamassassin:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash -e
      exec spamc --username="$USER"
  - require:
    - {{ dovecot.top_config_dir }}/sieve-filter-bin exists
    - {{ mail_storage.spamc_config_file }}
  - require_in:
    - {{ dovecot.top_config_dir }}/sieve-filter-bin is clean

{{ dovecot.top_config_dir }}/sieve-before exists:
  file.directory:
  - name: {{ dovecot.top_config_dir }}/sieve-before
  - require:
    - dovecot_pkgs
{{ dovecot.top_config_dir }}/sieve-before is clean:
  file.directory:
  - name: {{ dovecot.top_config_dir }}/sieve-before
  - clean: true
  - require:
    - {{ dovecot.top_config_dir }}/sieve-before exists

{{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.sieve:
  file.managed:
  - source: salt://mail/storage/spamassassin.sieve
  - require:
    - {{ dovecot.top_config_dir }}/sieve-before exists
    - {{ dovecot.top_config_dir }}/sieve-filter-bin/spamassassin
  - require_in:
    - {{ dovecot.top_config_dir }}/sieve-before is clean
{{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.svbin:
  cmd.run:
  - name: sievec {{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.sieve
  - require:
    - mail_storage_pkgs
    - {{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.sieve
    # Compilation fails unless vnd.dovecot.filter is configured and sieve_before
    # is set to indicate that this is a global script being compiled.
    - {{ dovecot.config_dir }}/50-mail-storage.conf
  - unless:
    - >-
        [[
        {{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.svbin
        -nt
        {{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.sieve
        ]]
  file.exists:
  - require:
    - cmd: {{ dovecot.top_config_dir }}/sieve-before/20-spamassassin.svbin
  - require_in:
    - {{ dovecot.top_config_dir }}/sieve-before is clean

# TODO(dovecot > 2.3.16): Remove this workaround. See
# https://dovecot.org/pipermail/dovecot/2021-August/122852.html for context.
{{ dovecot.config_dir }}/mail-storage-secrets.conf.ext:
  file.managed:
  - source: salt://mail/storage/dovecot-secrets.conf.jinja
  - mode: 0600
  - template: jinja
  - defaults:
      certificates: {{ certificates | tojson }}
      default_certificate: {{ certificates.values() | first | tojson }}
  - require:
    - {{ dovecot.config_dir }} exists
    {% for certificate in certificates.values() %}
    - {{ certificate.key }}
    {% endfor %}
  - require_in:
    - {{ dovecot.config_dir }} is clean
  - watch_in:
    - dovecot_running

{{ dovecot.config_dir }}/50-mail-storage.conf:
  file.managed:
  - source: salt://mail/storage/dovecot.conf.jinja
  - template: jinja
  - defaults:
      certificates: {{ certificates | tojson }}
      default_certificate: {{ certificates.values() | first | tojson }}
  - require:
    - {{ dovecot.config_dir }} exists
    - mail_storage_pkgs
    - vmail user and group
    - /var/local/mail/persistent/mail
    - {{ dovecot.top_config_dir }}/sieve-filter-bin is clean
    - {{ dovecot.top_config_dir }}/sieve-before exists
    - {{ common.local_etc }}/mail is clean
    - /var/cache/mail
    {% for certificate in certificates.values() %}
    - {{ certificate.fullchain }}
    {% endfor %}
    - {{ dovecot.config_dir }}/mail-storage-secrets.conf.ext
    - stunnel_pkgs
  - require_in:
    - {{ dovecot.config_dir }} is clean
  - watch_in:
    - dovecot_running

# I don't see any way to configure Dovecot to require specific client certs, so
# this uses stunnel instead.
{{ stunnel.instance(
    instance_name='lmtp',
    client=False,
    level='strict',
    accept=':::24',
    key=system_certificate.key,
    cert=system_certificate.fullchain,
    peer_certs=pillar.mail.common.inbound.certificates,
    connect=dovecot.base_dir + '/lmtp',
) }}


{% for mailbox_domain in pillar.mail.mailbox_domains %}
{{ common.local_etc }}/mail/{{ mailbox_domain }} exists:
  file.directory:
  - name: {{ common.local_etc }}/mail/{{ mailbox_domain }}
  - require:
    - {{ common.local_etc }}/mail exists
{{ common.local_etc }}/mail/{{ mailbox_domain }} is clean:
  file.directory:
  - name: {{ common.local_etc }}/mail/{{ mailbox_domain }}
  - clean: true
  - require:
    - {{ common.local_etc }}/mail/{{ mailbox_domain }} exists
  - require_in:
    - {{ common.local_etc }}/mail is clean
{% endfor %}

{% for account_name, account in pillar.mail.accounts.items() %}
{% set account_user, account_domain = account_name.split('@') %}
{{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }} exists:
  file.directory:
  - name: {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}
  - require:
    - {{ common.local_etc }}/mail/{{ account_domain }} exists
{{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }} is clean:
  file.directory:
  - name: {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}
  - clean: true
  - require:
    - {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }} exists
  - require_in:
    - {{ common.local_etc }}/mail/{{ account_domain }} is clean
/var/cache/mail/{{ account_domain }}/{{ account_user }}:
  file.directory:
  - user: vmail
  - group: vmail
  - dir_mode: 0700
  - makedirs: true
  - require:
    - /var/cache/mail

{{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve exists:
  file.directory:
  - name: {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve
  - require:
    - {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }} exists
{{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve is clean:
  file.directory:
  - name: {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve
  - clean: true
  - require:
    - {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve exists
  - require_in:
    - {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }} is clean

{% for sieve_name, sieve_contents in account.sieve.items() %}
{{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve/{{ sieve_name }}:
  file.managed:
  - contents: {{ sieve_contents | tojson }}
  - require:
    - {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve exists
  - require_in:
    - {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve is clean
{% endfor %}

# This is in the cache dir instead of the etc dir because of
# https://dovecot.org/pipermail/dovecot/2021-October/123084.html
/var/cache/mail/{{ account_domain }}/{{ account_user }}/active.sieve:
  file.symlink:
  - target: {{ common.local_etc }}/mail/{{ account_domain }}/{{ account_user }}/sieve/main.sieve
  - user: vmail
  - group: vmail
  - require:
    - /var/cache/mail/{{ account_domain }}/{{ account_user }}
{% endfor %}


{{ common.local_lib }}/mail-storage-monitor-subscriptions:
  file.managed:
  - source: salt://mail/storage/monitor_subscriptions.py
  - mode: 0755
  - require:
    - dovecot_running
  cron.present:
  - user: vmail
  - identifier: 68d9cd66-2692-4359-ac75-6fd07030453e
  - minute: random
  - hour: random
  - require:
    - file: {{ common.local_lib }}/mail-storage-monitor-subscriptions


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
