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


include:
- cryptsetup


ephemeral_swap_crypttab:
  file.blockreplace:
  - name: /etc/crypttab
  - marker_start: '# START: salt cryptsetup.ephemeral_swap :#'
  - marker_end: '# END: salt cryptsetup.ephemeral_swap :#'
  - content: |
      {%- for uuid in salt['pillar.get']('cryptsetup:ephemeral_swap', {}) %}
      {{ ' '.join((
          'ephemeral-swap-' + uuid,
          'UUID=' + uuid,
          '/dev/urandom',
          ','.join((
              'plain',
              'cipher=' + crypto.cryptsetup.cipher,
              'size=' + (crypto.cryptsetup.key_size | string),
              'offset=' + ((1024 * 1024 // 512) | string),
              'discard',
              'swap',
          )),
      )) }}
      {%- endfor %}
  - append_if_not_found: true
  - require:
    - cryptsetup_pkgs
  {% if salt['pillar.get']('cryptsetup:ephemeral_swap', {}) %}
  cmd.run:
  - name: >-
      cryptdisks_start
      {%- for uuid in pillar.cryptsetup.ephemeral_swap %}
      ephemeral-swap-{{ uuid }}
      {%- endfor %}
  - onchanges:
    - file: ephemeral_swap_crypttab
  {% endif %}

ephemeral_swap_fstab:
  file.blockreplace:
  - name: /etc/fstab
  - marker_start: '# START: salt cryptsetup.ephemeral_swap :#'
  - marker_end: '# END: salt cryptsetup.ephemeral_swap :#'
  - content: |
      {%- for uuid in salt['pillar.get']('cryptsetup:ephemeral_swap', {}) %}
      /dev/mapper/ephemeral-swap-{{ uuid }} none swap defaults 0 0
      {%- endfor %}
  - append_if_not_found: true
  - require:
    - ephemeral_swap_crypttab
  cmd.run:
  - name: >-
      swapon --verbose --all 2>&1
  - onchanges:
    - file: ephemeral_swap_fstab


{% for entry in salt.mount.fstab().values()
    if entry.fstype == 'swap' and
    not entry.device.startswith('/dev/mapper/ephemeral-swap-') %}
{{ entry.device }} should be removed from /etc/fstab:
  test.fail_without_changes: []
{% endfor %}
