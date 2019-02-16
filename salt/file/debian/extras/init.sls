# Copyright 2019 Google LLC
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


# Salt's debconf state doesn't work without this.
debconf-utils:
  pkg.installed: []

apt-listbugs:
  pkg.installed: []

apt-listchanges:
  debconf.set:
  - data:
      apt-listchanges/frontend:
        type: select
        value: mail
  pkg.installed: []

unattended-upgrades:
  pkg.installed: []
  file.managed:
  - name: /etc/apt/apt.conf.d/50unattended-upgrades-local
  - source: salt://debian/extras/unattended-upgrades-local.apt.conf

# unattended-upgrades requires a package that provides mailx in order to send
# email. mailutils provides mailx.
mailutils:
  pkg.installed: []
