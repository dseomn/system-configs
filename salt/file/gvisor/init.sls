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


{% if grains.os_family != 'Debian' %}
error:
  cmd.run:
  - name: 'echo "Error: Unsupported platform." >&2; exit 1'
{% endif %}


# https://gvisor.dev/docs/user_guide/install/#install-from-an-apt-repository
/etc/apt/trusted.gpg.d/gvisor.asc:
  file.managed:
  - source: https://gvisor.dev/archive.key
  - source_hash: 14f9edb6a623b335f29d26a11e7a458652c252bce0e1f15fcc8bdf02f97283c2e2eb2de89e65cfc6088d90cf5d7410bd9dde9a2821b0beb014e7500356a0c4fc
"deb https://storage.googleapis.com/gvisor/releases release main":
  pkgrepo.managed:
  - file: /etc/apt/sources.list.d/gvisor.list
runsc:
  pkg.installed: []

# TODO(https://github.com/google/gvisor/issues/3481): Delete this.
/etc/default/grub.d/systemd-cgroup-hybrid.cfg:
  file.managed:
  - contents: >
      GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX}
      systemd.unified_cgroup_hierarchy=0
      systemd.legacy_systemd_cgroup_controller=0"
update-grub:
  cmd.run:
  - onchanges:
    - file: /etc/default/grub.d/systemd-cgroup-hybrid.cfg
