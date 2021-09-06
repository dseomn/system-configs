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

irc:

  bouncer:

    # Required. DNS name of the bouncer. Used to get an ACME certificate.
    name: irc-bouncer.example.com

    # Required. znc configuration.
    znc:

      # Required. znc users.
      users:

        # Username.
        alice:

          # Required. "Real" name.
          real_name: Alice

          # Required. Run `znc --makepass` to create this.
          pass_section: |
            <Pass password>
              Method = sha256
              Hash = ...
              Salt = ...
            </Pass>

          # Required. Networks.
          networks:

            # Network name.
            libera:

              # Required. Server.
              server: irc.libera.chat +6697

              # Required. SASL password.
              password: ...

              # Required. Channels.
              channels:
              - '#libera'
