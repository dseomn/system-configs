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
  - cron
  - disk_usage
  - lost_found
  - mail.local_relay
  - trim
  - uptime

  'not G@role:kubernetes':
  - network.firewall.enable

  'G@os:Debian and G@debian:track:*':
  - debian
  - debian.extras

  'G@virtual:physical':
  - convenience.physical
  - firmware
  - power
  - smartd

  'G@role:access-point':
  - network.interfaces
  - network.local_resolver
  - ssh.server
  - standard

  'G@role:desktop':
  - gdm
  - google.chrome
  - network.firewall.ssdp.client
  - plymouth

  'G@role:desktop:basic':
  - desktop.basic
  - ssh.server

  'G@role:dev':
  - gvisor

  'G@role:home-router':
  - ddns
  - network.home_router
  - network.interfaces
  - network.local_resolver
  - ssh.server
  - standard

  'G@role:irc:bouncer':
  - irc.bouncer

  'G@role:kubernetes':
  - kubernetes
  - kubernetes.runtime
  - network.interfaces
  - network.local_resolver
  - ssh.server
  - standard

  'G@role:media-center':
  - dlna.renderer
  - ssh.server

  'G@role:news-aggregator':
  - news_aggregator

  'G@role:vcs':
  - vcs

  'G@role:virtual-machine:guest':
  - ssh.server
  - standard
  - virtual_machine.guest

  'G@role:virtual-machine:host':
  - network.interfaces
  - network.local_resolver
  - ssh.server
  - standard
  - virtual_machine.host

  'G@role:xmpp':
  - xmpp
