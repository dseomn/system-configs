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


{% from 'backup/map.jinja' import backup %}
{% from 'backup/source/map.jinja' import backup_source %}
{% from 'ssh/map.jinja' import ssh %}

{% set source_host = pillar.backup.source_hosts[grains.id] %}
{% set repository = pillar.backup.repositories[source_host.repository] %}
{% set repository_host = pillar.backup.repository_hosts[repository.primary] %}

{% if repository.type == 'borg' %}
  {% set borg_repo = 'backup-{}@{}:{}.borg'.format(
      source_host.repository,
      repository.primary,
      source_host.repository,
  ) %}
{% else %}
  {{ {}['Unsupported repo type: ' + repository.type] }}
{% endif %}


include:
- backup
- crypto.secret_rotation


backup_source_pkgs:
  pkg.installed:
  - pkgs: {{ backup_source.pkgs | tojson }}


{{ backup.config_dir }}/source:
  file.directory:
  - require:
    - {{ backup.config_dir }}


create_backup_source_sources_d:
  file.directory:
  - name: {{ backup.config_dir }}/source/sources.d
  - require:
    - {{ backup.config_dir }}/source
manage_backup_source_sources_d:
  file.directory:
  - name: {{ backup.config_dir }}/source/sources.d
  - clean: true
  - require:
    - create_backup_source_sources_d


{{ backup.config_dir }}/source/ssh:
  file.directory:
  - mode: 0700
  - require:
    - {{ backup.config_dir }}/source

{{ ssh.key(
    backup.config_dir + '/source/ssh/id',
    warning_on_change=(
        'Update salt/pillar/backup/data.yaml.jinja with new SSH public key.'),
    require=(backup.config_dir + '/source/ssh',),
) }}

{{ backup.config_dir }}/source/ssh/known_hosts:
  file.managed:
  - contents: |
      {{ repository.primary }} {{ repository_host.ssh_host_public_key }}
      {%- for dump_host_name, dump_host in pillar.backup.dump_hosts.items()
          if dump_host.source == grains.id %}
      {{ dump_host_name }} {{ dump_host.ssh_host_public_key }}
      {%- endfor %}
  - require:
    - {{ backup.config_dir }}/source/ssh

{{ backup.config_dir }}/source/ssh/config:
  file.managed:
  - contents: |
      Match all
        IdentityFile {{ backup.config_dir }}/source/ssh/id
        StrictHostKeyChecking yes
        UserKnownHostsFile {{ backup.config_dir }}/source/ssh/known_hosts
  - require:
    - {{ backup.config_dir }}/source/ssh
    - {{ backup.config_dir }}/source/ssh/id
    - {{ backup.config_dir }}/source/ssh/known_hosts


{{ backup.data_dir }}/source:
  file.directory:
  - require:
    - {{ backup.data_dir }}


{{ backup_source.backup_exec }}:
  file.managed:
  - mode: 0755
  - source: salt://backup/source/backup_exec.py.jinja
  - template: jinja


{{ backup_source.backup_source_borg }}:
  file.managed:
  - mode: 0755
  - contents: |
      #!/bin/bash -e
      export BORG_REPO='{{ borg_repo }}'
      export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
      exec borg --rsh='ssh -F {{ backup.config_dir }}/source/ssh/config' "$@"
  - require:
    - {{ backup.config_dir }}/source/ssh/config
    - backup_source_pkgs

backup_source_borg:
  cron.present:
  - name: >-
      {{ backup_source.backup_exec }}
      --backup-dir={{ backup.data_dir }}/source/borg
      --
      {{ backup_source.backup_source_borg }}
      --lock-wait {{ backup.borg_lock_wait_noninteractive }}
      create
      --numeric-ids
      '::auto-{{ source_host.repository }}-{utcnow:\%Y\%m\%dT\%H\%M\%SZ}'
      .
  - identifier: 9fb0268b-97eb-4c67-a4cb-f186e445eac9
  - minute: random
  - hour: random
  - require:
    - {{ backup_source.backup_exec }}
    - manage_backup_source_sources_d
    - {{ backup.data_dir }}/source
    - {{ backup_source.backup_source_borg }}
