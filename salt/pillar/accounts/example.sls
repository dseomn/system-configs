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

accounts:

  # Required. DNS name of the service.
  name: accounts.example.com

  # Required. Users.
  users:
    # Username.
    alice:
      # Required. Email address.
      email: alice@example.com
      # Required. Name.
      name: Alice Example

  # Required. OpenID Connect configuration.
  oidc:
    # Required. Relying parties.
    rps:
      some-client.example.com:
        # Required. Redirection URIs.
        redirection_uris:
        - https://some-client.example.com
