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


/etc/NetworkManager/conf.d/50-power.conf:
  file.managed:
  - makedirs: true
  - contents: |
      [connection]
      # Disable wifi power saving, since it seems to make inbound connections
      # much slower. Running `ping -i 0.2 -c 20` with power saving on:
      #
      # rtt min/avg/max/mdev = 2.910/195.265/515.304/135.881 ms, pipe 3
      #
      # And off:
      #
      # rtt min/avg/max/mdev = 1.609/4.878/16.962/4.599 ms
      #
      # Values are from
      # https://github.com/NetworkManager/NetworkManager/blob/0d10c743a5787747f644ab57bbe2856ccf33aab2/src/libnm-core-public/nm-setting-wireless.h#L129-L147
      wifi.powersave=2


/etc/systemd/logind.conf.d/50-power.conf:
  file.managed:
  - makedirs: true
  - source: salt://power/logind.conf.jinja
  - template: jinja
warn about systemd-logind:
  test.configurable_test_state:
  - warnings: Reboot to pick up changes to systemd-logind.
  - onchanges:
    - /etc/systemd/logind.conf.d/50-power.conf
