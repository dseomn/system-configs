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

xmpp:

  # Maximum number of passwords a single user can have configured below.
  # Default: 25.
  max_passwords_per_user: 25

  # Required. Domains to serve XMPP for.
  domains:

    example.com:

      # Required. Users in the domain.
      users:

        alice:
          # Required. Hashed salted passwords. See
          # https://passlib.readthedocs.io/en/stable/lib/passlib.hash.html for
          # how to generate them.
          crypted_passwords:
          - '$6$...'
