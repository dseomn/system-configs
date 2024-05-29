# Copyright 2024 Google LLC
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


{% from 'common/map.jinja' import common %}


syslog_ng_pkgs:
  pkg.installed:
  - pkgs:
    - syslog-ng-core

syslog_ng_enabled:
  service.enabled:
  - name: syslog-ng.service
  - require:
    - syslog_ng_pkgs

syslog_ng_running:
  service.running:
  - name: syslog-ng.service
  - require:
    - syslog_ng_pkgs

{{ common.system_user_and_group('syslog-ng', groups=('adm',)) }}

/etc/default/syslog-ng:
  file.managed:
  - contents: |
      SYSLOGNG_OPTS="--user=syslog-ng --group=syslog-ng --no-caps"
  - require:
    - syslog_ng_pkgs
    - syslog-ng user and group
  - watch_in:
    - syslog_ng_running

/var/lib/syslog-ng:
  file.directory:
  - user: syslog-ng
  - group: syslog-ng
  - recurse:
    - user
    - group
  - require:
    - syslog_ng_pkgs
    - syslog-ng user and group
  - watch_in:
    - syslog_ng_running

/etc/syslog-ng/conf.d exists:
  file.directory:
  - name: /etc/syslog-ng/conf.d
  - require:
    - syslog_ng_pkgs
/etc/syslog-ng/conf.d is clean:
  file.directory:
  - name: /etc/syslog-ng/conf.d
  - clean: true
  - require:
    - /etc/syslog-ng/conf.d exists
  - watch_in:
    - syslog_ng_running

/etc/syslog-ng/syslog-ng.conf:
  file.managed:
  - contents: |
      @version: 3.38
      @include "scl.conf"
      options {
        frac-digits(9);
        keep-hostname(yes);
        mark-mode(none);
        time-reopen(10);
        trim-large-messages(yes);
        use-dns(no);
        use-fqdn(yes);
      };
      source s_internal {
        internal();
      };
      destination d_system {
        unix-dgram(
          "/dev/log"
          # Guessed by using `nc -lkU` to listen on a socket and `logger -u` to
          # send to it.
          frac-digits(0)
          template("<${PRI}>${R_DATE} ${MSGHDR}${MESSAGE}\n")
        );
      };
      log {
        source(s_internal);
        destination(d_system);
        flags(flow-control);
      };
      @include "/etc/syslog-ng/conf.d/*.conf"
  - require:
    - syslog_ng_pkgs
    - /etc/syslog-ng/conf.d is clean
  - watch_in:
    - syslog_ng_running
