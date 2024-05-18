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


debian_extras_pkgs:
  pkg.installed:
  - pkgs:
    - apt-listbugs
    - apt-listchanges
    - aptitude
    - debconf-utils
    - debian-security-support
    - mailutils  # Provides mailx which unattended-upgrades needs to send email.
    - unattended-upgrades


/etc/apt/listchanges.conf.d/local.conf:
  file.managed:
  - contents: |
      [apt]
      frontend=mail
      headers=true


unattended-upgrades:
  file.managed:
  - name: /etc/apt/apt.conf.d/50unattended-upgrades-local
  - source: salt://debian/extras/unattended-upgrades-local.apt.conf

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


# Shows packages in some unexpected states:
#
# * Obsolete packages, i.e., ones that are not in any configured archive. This
#   excludes packages tagged local, since those were intentionally installed
#   from outside of an archive. It also excludes versioned kernel packages,
#   since those are handled specially by apt autoremove. See
#   /etc/apt/apt.conf.d/01autoremove for more detail about versioned kernel
#   packages.
# * Packages tagged as local that are in an archive. (So that the tag can be
#   removed when a formerly local package is added to an archive.)
show_packages_in_unexpected_state:
  cron.present:
  - name: >-
      aptitude
      search
      --display-format='\%t \%p'
      '?obsolete !?user-tag(local) !?name(^linux-.*[0-9]+\.[0-9]+)'
      '?user-tag(local) !?obsolete'
      ||
      true
  - identifier: ccb4bc08-78a1-43b0-b08b-263032e5de83
  - minute: random
  - hour: random
  - dayweek: random
  - require:
    - debian_extras_pkgs
