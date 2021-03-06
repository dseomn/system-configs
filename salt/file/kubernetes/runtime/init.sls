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


include:
- gvisor


containerd:
  pkg.installed: []

/etc/containerd/runsc.local.toml:
  file.managed:
  - source: salt://kubernetes/runtime/containerd.runsc.local.toml.jinja
  - template: jinja
  - require:
    - sls: gvisor

/etc/containerd/local.toml:
  file.managed:
  - source: salt://kubernetes/runtime/containerd.local.toml.jinja
  - template: jinja

/etc/systemd/system/containerd.service.d/50-local.conf:
  file.managed:
  - source: salt://kubernetes/runtime/containerd.local.service.conf
  - makedirs: true

containerd_unit_reload:
  cmd.run:
  - name: systemctl daemon-reload
  - onchanges_any:
    - file: /etc/systemd/system/containerd.service.d/50-local.conf

containerd.service:
  service.running:
  - enable: true
  - watch_any:
    - file: /etc/containerd/runsc.local.toml
    - file: /etc/containerd/local.toml
    - cmd: containerd_unit_reload


/etc/crictl.yaml:
  file.managed:
  - source: salt://kubernetes/runtime/crictl.yaml.jinja
  - template: jinja
