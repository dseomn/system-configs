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

mail:

  common:

    # Required. How to connect to mail.inbound hosts.
    inbound:
      # Required. DNS name that points to mail.inbound host(s).
      name: mail-inbound.example.com
      # Required. Server certificates that will be used for the name above.
      certificates:
      - |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----

    # Required. How to connect to mail.outbound hosts. Same structure as inbound
    # above.
    outbound:
      name: mail-outbound.example.com
      certificates:
      - |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----

    # Required. How to connect to mail.storage hosts.
    storage:
      # Required. DNS name that points to mail.storage host(s) collectively.
      name: mail-storage.example.com
      # Required. Certificates that will be used for the name above. There must
      # be exactly 1 or 2 entries here, because
      # https://doc.dovecot.org/configuration_manual/replication/ says
      # "Replication works only between server pairs."
      certificate_by_minion:
        # Key: DNS name and minion ID of a specific mail.storage host. Value:
        # Certificate.
        mail-storage-1.example.com: |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----
