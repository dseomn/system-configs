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

port_mux:

  # Required by port_mux servers. TLS port multiplexing.
  tls:

    # Server name from the SNI extension.
    some-service.example.com:
      # Multiplexed port.
      443:
        # Required. Backend. See
        # https://nginx.org/en/docs/stream/ngx_stream_proxy_module.html#proxy_pass
        # for the syntax. The backend must support the proxy protocol.
        backend: some-backend.example.com:443

  # Required by port_mux backends.
  upstream:

    # List of IPv6 upstreams.
    ipv6:
    - 2001:db8::1
