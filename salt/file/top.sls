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
  - cryptsetup.ephemeral_swap
  - disk_usage
  - grub
  - lost_found
  - mail
  - mount
  - network.firewall.enable
  - trim
  - uptime

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

  'G@role:accounts':
  - accounts

  'G@role:backup:repo':
  - backup.repo

  'G@role:ddns':
  - ddns

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

  'G@role:hp-printer':
  - hp_printer

  'G@role:irc:bouncer':
  - irc.bouncer

  'G@role:mail:inbound':
  - mail.inbound

  'G@role:mail:outbound':
  - mail.outbound

  'G@role:mail:storage':
  - mail.storage

  'G@role:mail:web':
  - mail.web

  'G@role:media-center':
  - media_center
  - plymouth
  - ssh.server

  'G@role:media-tracker':
  - media_tracker

  'G@role:nas':
  - nas
  - nas.http
  - nas.nfs
  - nas.rsync
  - nas.smb

  'G@role:network:managed':
  - network.interfaces
  - network.local_resolver

  'G@role:news-aggregator':
  - news_aggregator

  'G@role:nextcloud':
  - nextcloud

  'G@role:port-mux':
  - ddns
  - port_mux

  'G@role:todo':
  - todo

  'G@role:vcs':
  - vcs

  'G@role:virtual-machine:guest':
  - network.interfaces
  - network.local_resolver
  - ssh.server
  - standard
  - virtual_machine.guest

  'G@role:virtual-machine:host':
  - network.interfaces
  - network.local_resolver
  - ssh.server
  - standard
  - virtual_machine.host

  'G@role:watchdog':
  - watchdog

  'G@role:web:static':
  - web.static

  'G@role:xmpp':
  - xmpp
