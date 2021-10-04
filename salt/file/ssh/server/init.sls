# Copyright 2020 Google LLC
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


{% set sshd = salt.grains.filter_by({
    'Debian': {
        'pkg': 'openssh-server',
        'service': 'ssh',
        'config_directory': '/etc/ssh',
        'sftp_command': '/usr/lib/openssh/sftp-server',
    },
}) %}

{% from 'network/firewall/map.jinja' import nftables %}
{% from 'ssh/map.jinja' import ssh %}


include:
- network.firewall
- crypto.secret_rotation


ssh-server-config-changed:
  test.configurable_test_state:
  - warnings: "Test ssh with: ssh -S none {{ grains.id }}"


sshd_pkg:
  pkg.installed:
  - name: {{ sshd.pkg }}

sshd_enabled:
  service.enabled:
  - name: {{ sshd.service }}

sshd_running:
  service.running:
  - name: {{ sshd.service }}
  - watch:
    - file: sshd_config
    - {{ sshd.config_directory }}/ssh_host_key

{{ ssh.key(
    sshd.config_directory + '/ssh_host_key',
    warning_on_change=(
        'Update ~/.ssh/known_hosts with new SSH host public key. Possibly also '
        'update salt/pillar/backup/source/init.sls'),
) }}

sshd_config:
  file.managed:
  - name: {{ sshd.config_directory }}/sshd_config
  - onchanges_in:
    - ssh-server-config-changed
  - source: salt://ssh/server/sshd_config.jinja
  - template: jinja
  - defaults:
      sshd: {{ sshd | tojson }}
  - require:
    - {{ sshd.config_directory }}/ssh_host_key

sshd_port:
  file.managed:
  - name: {{ nftables.config_dir }}/50-ssh.conf
  - onchanges_in:
    - ssh-server-config-changed
    - warn about firewall changes
  - source: salt://ssh/server/nftables.conf
  - require:
    - create_nftables_config_dir
  - require_in:
    - manage_nftables_config_dir


{% for user, user_config in pillar.users.users.items()
    if 'authorized_keys' in user_config.get('ssh', {}) %}

~{{ user }}/.ssh:
  file.directory:
  - user: {{ user }}
  - group: {{ user }}
  - mode: 0700
  - onchanges_in:
    - ssh-server-config-changed

~{{ user }}/.ssh/authorized_keys:
  file.managed:
  - user: {{ user }}
  - group: {{ user }}
  - onchanges_in:
    - ssh-server-config-changed
  - contents_pillar: users:users:{{ user }}:ssh:authorized_keys

{% endfor %}


/root/.ssh:
  file.directory:
  - mode: 0700

/root/.ssh/authorized_keys:
  file.managed:
  - source: salt://ssh/server/authorized_keys_accumulated.jinja
  - template: jinja
