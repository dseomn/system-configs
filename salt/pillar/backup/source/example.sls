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


backup:

  # Configuration for this minion as a source/creator of backups.
  source:

    # Required. ssh configuration.
    ssh:
      # Required. known_hosts file contents to use for creating backups.
      known_hosts: |
        borg.example.com ecdsa-sha2-nistp256 ...

    # Required. borgbackup configuration.
    borg:
      # Required. Repository to create backups in.
      repo: borg@borg.example.com:/path/to/repo
      # Required. Name of archives to create, optionally including placeholders.
      archive: '{hostname}-{utcnow:%Y%m%dT%H%M%SZ}'
