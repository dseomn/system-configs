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


{% from 'kubernetes/map.jinja' import kubernetes %}


{% if grains.os_family != 'Debian' %}
error:
  cmd.run:
  - name: 'echo "Error: Unsupported platform." >&2; exit 1'
{% endif %}


# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic
br_netfilter:
  kmod.present:
  - persist: true
net.bridge.bridge-nf-call-ip6tables:
  sysctl.present:
  - value: 1
net.bridge.bridge-nf-call-iptables:
  sysctl.present:
  - value: 1

net.ipv4.ip_forward:
  sysctl.present:
  - value: 1
net.ipv6.conf.all.forwarding:
  sysctl.present:
  - value: 1


# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
/etc/apt/trusted.gpg.d/kubernetes.gpg:
  file.managed:
  - source: https://packages.cloud.google.com/apt/doc/apt-key.gpg
  - source_hash: 28c3148162ef30b432bd3fd88ea535a569f9d4c72a5b4bcec21e6419f4ffb9addd0cda408637e902c5039007a160282b919e6ef78fcc6b8069db5da725154318
"deb https://apt.kubernetes.io kubernetes-xenial main":
  pkgrepo.managed:
  - file: /etc/apt/sources.list.d/kubernetes.list
kubernetes_pkgs:
  pkg.installed:
  - pkgs: {{ kubernetes.pkgs | json }}
  - hold: true


/etc/kubernetes/kubeadm.yaml:
  file.managed:
  - source: salt://kubernetes/kubeadm.yaml.jinja
  - template: jinja
