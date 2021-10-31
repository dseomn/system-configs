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

cron:

  # Extra cron jobs that aren't in another salt state.
  jobs:

    # User that the jobs run as.
    root:

      # Part of the job identifier.
      test-cron:
      # Args to
      # <https://docs.saltproject.io/en/latest/ref/states/all/salt.states.cron.html#salt.states.cron.present>.
      # Must not include user or identifier.
      - name: echo test cron
      - minute: random
      - hour: random
