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

nas:

  # Hostname to get certificates for.
  hostname: nas.example.com

  # Required. Shares. (Or NFS exports, rsync modules, etc.)
  shares:

    # Share/module name. Ignored for protocols like NFS that don't have that
    # concept. Can't be 'global' (reserved by rsync and samba), 'homes', or
    # 'printers' (reserved by samba).
    stuff:
      # Required. Path to the data. Must be the mountpoint of a virtual machine
      # guest volume.
      volume: /srv/stuff
      # If true, a state requirement will be added to make sure that this
      # share's volume is backed up. Default: true.
      backup: true
