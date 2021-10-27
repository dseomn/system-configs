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
{% from 'backup/repo/map.jinja' import backup_repo %}
{% from 'common/map.jinja' import common %}

{% set source_host_name_by_repository = {} %}
{% for source_host_name, source_host in pillar.backup.source_hosts.items() %}
  {% do source_host_name_by_repository.update(
      {source_host.repository: source_host_name}) %}
{% endfor %}


{% macro pv(name, rate_limit) -%}
  pv --quiet --name {{ name }}
  {%- if rate_limit is not none %} --rate-limit {{ rate_limit }}{% endif -%}
{%- endmacro %}


{% macro restricted_authorized_key(
    directory,
    command,
    upload_limit,
    download_limit,
    public_key,
    comment) -%}
  {{ ''.join((
      'restrict,command="',
      'cd ',
      directory,
      ' && ',
      pv(name='upload', rate_limit=upload_limit),
      ' | ',
      command,
      ' | ',
      pv(name='download', rate_limit=download_limit),
      '" ',
      public_key,
      ' ',
      comment,
  )) }}
{%- endmacro %}


{% macro borg_check(repo_path) -%}
  {{ ' '.join((
      'BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes',
      'borg',
      '--lock-wait',
      backup.borg_lock_wait_noninteractive | string,
      'check',
      '--verify-data',
      repo_path,
  )) }}
{%- endmacro %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- backup
- common
- virtual_machine.guest


backup_repo_pkgs:
  pkg.installed:
  - pkgs: {{ backup_repo.pkgs | tojson }}


{% set old_backup_users_and_groups = {} %}
{% for user in salt.user.list_users() if user.startswith('backup-') %}
  {% do old_backup_users_and_groups.update({user: None}) %}
{% endfor %}
{% for group in salt.group.getent() if group.name.startswith('backup-') %}
  {% do old_backup_users_and_groups.update({group.name: None}) %}
{% endfor %}

{{ backup.data_dir }}/users exists:
  file.directory:
  - name: {{ backup.data_dir }}/users
{{ backup.data_dir }}/users is clean:
  file.directory:
  - name: {{ backup.data_dir }}/users
  - clean: true
  - require:
    - {{ backup.data_dir }}/users exists

{{ common.system_user_and_group(
    'backup-default',
    home=backup.data_dir + '/users/backup-default',
    createhome=True,
    shell=None,
) }}
{{ backup.data_dir }}/users/backup-default:
  file.directory:
  - user: backup-default
  - group: backup-default
  - dir_mode: 0700
  - require:
    - backup-default user and group
  - require_in:
    - {{ backup.data_dir }}/users is clean
{% do old_backup_users_and_groups.pop('backup-default', None) %}


{{ backup.data_dir }}/repo:
  file.directory:
  - require:
    - {{ backup.data_dir }}
    - {{ backup.data_dir }}/repo is mounted
    # Prevent loops.
    - {{ backup.data_dir }}/repo is not backed up


# https://borgbackup.readthedocs.io/en/stable/quickstart.html#important-note-about-free-space
{% set reserved_space_mb = 2 * 1024 %}
{% set reserved_space_bytes = reserved_space_mb * 1024 * 1024 %}
{% set reserved_space_file = backup.data_dir + '/repo/reserved-space' %}
{% if not salt.file.file_exists(reserved_space_file) or
    salt.file.stats(reserved_space_file).size != reserved_space_bytes %}
{{ reserved_space_file }}:
  cmd.run:
  - name: >-
      dd
      if=/dev/urandom
      of={{ reserved_space_file }}
      bs=1M
      count={{ reserved_space_mb }}
  - require:
    - {{ backup.data_dir }}/repo
{% endif %}


# Directory for things that could help with disaster or data recovery. Nothing
# authoritative (like backups) should go here, just copies of data that's
# currently available elsewhere. E.g., source code that could be useful for
# parsing the backups after the software used to create them is no longer
# available, or system configuration to get started on recovering infrastructure
# from zero while waiting for backups to extract.
{{ backup.data_dir }}/repo/recovery exists:
  file.directory:
  - name: {{ backup.data_dir }}/repo/recovery
  - require:
    - {{ backup.data_dir }}/repo
{{ backup.data_dir }}/repo/recovery is clean:
  file.directory:
  - name: {{ backup.data_dir }}/repo/recovery
  - clean: true
  - require:
    - {{ backup.data_dir }}/repo/recovery exists

{% macro recovery_public_git_repo(name, url, branch) %}
{{ backup.data_dir }}/repo/recovery/{{ name }}:
  file.directory:
  - user: backup-default
  - group: backup-default
  - require:
    - {{ backup.data_dir }}/repo/recovery exists
  - require_in:
    - {{ backup.data_dir }}/repo/recovery is clean
  git.latest:
  - name: {{ url }}
  - rev: {{ branch }}
  - target: {{ backup.data_dir }}/repo/recovery/{{ name }}
  - branch: {{ branch }}
  - user: backup-default
  - submodules: true
  - require:
    - file: {{ backup.data_dir }}/repo/recovery/{{ name }}
    - backup_repo_pkgs
  - require_in:
    - {{ backup.data_dir }}/repo/recovery is clean
{% endmacro %}

{{ recovery_public_git_repo(
    'borg',
    url='https://github.com/borgbackup/borg.git',
    branch='master',
) }}

# Spec for format used by Borg.
{{ recovery_public_git_repo(
    'msgpack',
    url='https://github.com/msgpack/msgpack.git',
    branch='master',
) }}

# Implementation of format used by Borg.
{{ recovery_public_git_repo(
    'msgpack-python',
    url='https://github.com/msgpack/msgpack-python.git',
    branch='main',
) }}

# TODO(dseomn): Add system-configs and dotfiles repos?


{% set old_repos = {} %}
{% macro scan_dir_for_old_repos(dir_name) %}
  {% if salt.file.directory_exists(dir_name) %}
    {% for filename in salt.file.readdir(dir_name)
        if filename not in ('.', '..') %}
      {% do old_repos.update({dir_name + '/' + filename: None}) %}
    {% endfor %}
  {% endif %}
{% endmacro %}

{{ backup.data_dir }}/repo/primary:
  file.directory:
  - require:
    - {{ backup.data_dir }}/repo
{% do scan_dir_for_old_repos(backup.data_dir + '/repo/primary') %}

{% for repo_name, repo in pillar.backup.repositories.items() %}

{% if repo.primary == grains.id %}

{% set repo_username = 'backup-' + repo_name %}
{% set repo_user_home = backup.data_dir + '/users/' + repo_username %}
{{ common.system_user_and_group(
    repo_username,
    home=repo_user_home,
    createhome=True,
    shell=None,
) }}
{{ repo_user_home }}:
  file.directory:
  - user: {{ repo_username }}
  - group: {{ repo_username }}
  - dir_mode: 0700
  - require:
    - {{ repo_username }} user and group
  - require_in:
    - {{ backup.data_dir }}/users is clean
{% do old_backup_users_and_groups.pop(repo_username, None) %}

{% set repo_path =
    backup.data_dir + '/repo/primary/' + repo_name + '.' + repo.type %}
{{ repo_path }}:
  file.directory:
  - user: {{ repo_username }}
  - group: {{ repo_username }}
  - dir_mode: 0700
  - require:
    - {{ backup.data_dir }}/repo/primary
    - {{ repo_username }} user and group
{% do old_repos.pop(repo_path, None) %}

{% set source_host_name = source_host_name_by_repository[repo_name] %}
{% set source_host = pillar.backup.source_hosts[source_host_name] %}
{{ repo_user_home }}/.ssh:
  file.directory:
  - user: {{ repo_username }}
  - group: {{ repo_username }}
  - dir_mode: 0700
  - require:
    - {{ repo_user_home }}
{{ repo_user_home }}/.ssh/authorized_keys:
  file.managed:
  - user: {{ repo_username }}
  - group: {{ repo_username }}
  - mode: 0600
  - contents: |
      {{ restricted_authorized_key(
          directory=backup.data_dir + '/repo/primary',
          command=' '.join((
              'borg',
              'serve',
              '--restrict-to-repository',
              repo_path,
              '--append-only',
          )),
          upload_limit=source_host.get('repo_upload_limit'),
          download_limit=source_host.get('repo_download_limit'),
          public_key=source_host.ssh_client_public_key,
          comment=source_host_name,
      ) }}
  - require:
    - {{ repo_user_home }}/.ssh

# TODO(dseomn): Monitor recency of backups.

check {{ repo_path }}:
  cron.present:
  - name: {{ borg_check(repo_path) | tojson }}
  - identifier: 0f85dd71-4c65-44a6-9ec3-23c279407557
  - user: {{ repo_username }}
  - minute: random
  - hour: random
  - dayweek: random
  - require:
    - {{ repo_username }} user and group
    - backup_repo_pkgs
    - {{ repo_path }}

{% elif repo.primary is not none %}

# TODO(dseomn): Replicate repository from the primary, including `borg check`.
# See
# https://borgbackup.readthedocs.io/en/stable/faq.html#can-i-copy-or-synchronize-my-repo-to-another-location
# for warnings.
# TODO(dseomn): Monitor recency of backups.
{{ {}['Unsupported.'] }}

{% else %}

# TODO(dseomn): Manage directory ownership and permissions, but do not create
# the directory. (Fail if the directory does not exist.)
# TODO(dseomn): Periodically run `borg check` if the type is 'borg'.
{{ {}['Unsupported.'] }}

{% endif %}

{% endfor %}

# This is important to ensure that everything in each backup drive is properly
# accounted for in salt/pillar/backup/data.yaml.jinja, so that all the other
# backup drives can be checked for completeness. It also makes it harder to
# accidentally have inactive borg repos that don't get regular `borg check`
# runs, and harder to accidentally leave files/directories around with incorrect
# ownership/permissions.
{% for repo in old_repos %}
{{ repo }} is unaccounted for in salt/pillar/backup/data.yaml.jinja:
  test.fail_without_changes: []
{% endfor %}


{% for name in old_backup_users_and_groups %}
{{ name }} user and group:
  cmd.run:
  - name: >-
      crontab -u {{ name }} -l && crontab -u {{ name }} -r
  - onlyif:
    - crontab -u {{ name }} -l > /dev/null
  user.absent:
  - name: {{ name }}
  - require:
    - {{ backup.data_dir }}/users is clean
    - cmd: {{ name }} user and group
  - require_in:
    - users and groups are done
  group.absent:
  - name: {{ name }}
  - require:
    - {{ backup.data_dir }}/users is clean
    - user: {{ name }} user and group
  - require_in:
    - users and groups are done
{% endfor %}
