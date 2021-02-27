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


sshd:
  pkg.installed:
  - name: {{ sshd.pkg }}
  service.running:
  - name: {{ sshd.service }}
  - enable: True
  - watch:
    - file: sshd_config

sshd_config:
  file.managed:
  - name: {{ sshd.config_directory }}/sshd_config
  - source: salt://ssh/server/sshd_config.jinja
  - template: jinja
  - defaults:
      sshd: {{ sshd | yaml }}

sshd_port:
  file.managed:
  - name: /etc/nftables.conf.d/ssh.conf
  - source: salt://ssh/server/nftables.conf
