# Copyright 2023 Google LLC
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

media_tracker:
  # Map from username to rock-paper-sand config file. The import_text tag from
  # salt's jinja renderer can be used to load the data from separate files.
  users:
    alice: |
      # See https://github.com/dseomn/rock-paper-sand for the config format.
