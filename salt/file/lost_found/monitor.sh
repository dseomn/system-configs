#!/bin/bash -e

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


mountpoints="$(lsblk --list --noheadings --output=MOUNTPOINT)"
while IFS= read -r mountpoint; do
  if
      [[ "$mountpoint" = /* ]] &&
      [[ -d "${mountpoint%/}/lost+found" ]] &&
      [[ -n "$(ls -A "${mountpoint%/}/lost+found")" ]] ;
  then
    printf '%s\n' "${mountpoint%/}/lost+found"
    ls -lA "${mountpoint%/}/lost+found"
    printf '\n'
  fi
done <<EOF
${mountpoints}
EOF
