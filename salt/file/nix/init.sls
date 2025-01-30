# Copyright 2025 David Mandelberg
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


{% from 'cron/map.jinja' import cron_job %}
{% from 'nix/map.jinja' import nix %}


include:
- cron


nix_pkgs:
  pkg.installed:
  - pkgs:
    - nix-bin

/etc/profile.d/nix-local.sh:
  file.managed:
  - contents: |
      # TODO(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1094663): Remove
      # this.
      export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
      # TODO(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1094662): Remove
      # this.
      export XDG_DATA_DIRS="$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"

nix_channels_done:
  test.nop: []

/etc/nix/packages:
  file.managed:
  - source: salt://nix/packages.jinja
  - template: jinja
  - require:
    - nix_channels_done

nix_system_default_profile:
  cmd.run:
  - name: |
      xargs \
        --arg-file=/etc/nix/packages \
        nix-env \
        --install \
        --attr \
        --remove-all
  - onchanges:
    - /etc/nix/packages

{{ cron_job(
    state_id='nix_upgrade',
    user='root',
    command=(
        'nix-channel --quiet --update && ' +
        'nix-env --quiet --upgrade && ' +
        'nix-env --quiet --delete-generations 30d && ' +
        'nix-store --quiet --gc'
    ),
    minute='?',
    hour='?',
    require=(
        'nix_pkgs',
    ),
) }}
