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
  pkg.installed: []

/etc/apt/listchanges.conf.d/local.conf:
  file.managed:
  - contents: |
      [apt]
      frontend=mail
      headers=true

aptitude:
  pkg.installed: []

debian-security-support:
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

# This is a crontab entry instead of using APT::Periodic::Update-Package-Lists
# and APT::Periodic::Unattended-Upgrade for a few reasons:
#   * https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=778878
#   * https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=833662
#   * unattended-upgrade doesn't seem to provide a way to send mail if and only
#     if there's something actionable to look at. Its idea of only sending mail
#     on error doesn't include when it's unable to upgrade some packages.
#     update-motd-unattended-upgrades should print a message in that case.
apt-get -qq update && unattended-upgrade && /usr/share/unattended-upgrades/update-motd-unattended-upgrades:
  cron.present:
  - identifier: 03d139b7-b29a-4bde-8e7d-2cf4dc58b52f
  - minute: random
  - hour: random
