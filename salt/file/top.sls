# Copyright 2019 Google LLC
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


base:
  '*':
  - convenience
  - mail

  'not G@role:kubernetes':
  - network.firewall.enable

  'G@os:Debian and G@debian:track:*':
  - debian
  - debian.extras

  'G@virtual:physical':
  - smartd

  'G@role:access-point':
  - network.interfaces
  - network.local_resolver
  - ssh.server

  'G@role:desktop':
  - gdm
  - google.chrome
  - network.firewall.ssdp.client
  - plymouth

  'G@role:home-router':
  - ddns
  - network.home_router
  - network.interfaces
  - network.local_resolver
  - ssh.server

  'G@role:kubernetes':
  - kubernetes
  - kubernetes.runtime
  - network.interfaces
  - network.local_resolver
  - ssh.server

  'G@role:media-center':
  - dlna.renderer
  - ssh.server
