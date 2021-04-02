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

kubernetes:
  # Required. Version of kubernetes packages.
  version: 1.20.5-00

  # Required. serviceSubnet field in
  # https://pkg.go.dev/k8s.io/kubernetes@v1.20.5/cmd/kubeadm/app/apis/kubeadm/v1beta2#Networking
  service_subnet: fdXX:XXXX:XXXX:YY00::/108,10.Y.0.0/16

  # Required. podSubnet field in
  # https://pkg.go.dev/k8s.io/kubernetes@v1.20.5/cmd/kubeadm/app/apis/kubeadm/v1beta2#Networking
  pod_subnet: fdXX:XXXX:XXXX:ZZ00::/56,10.Z.0.0/16

  # Required. dnsDomain field in
  # https://pkg.go.dev/k8s.io/kubernetes@v1.20.5/cmd/kubeadm/app/apis/kubeadm/v1beta2#Networking
  dns_domain: cluster.local

  # Required. controlPlaneEndpoint field in
  # https://pkg.go.dev/k8s.io/kubernetes@v1.20.5/cmd/kubeadm/app/apis/kubeadm/v1beta2#ClusterConfiguration
  control_plane_endpoint: kubernetes-control.example.com

  # Required. clusterName field in
  # https://pkg.go.dev/k8s.io/kubernetes@v1.20.5/cmd/kubeadm/app/apis/kubeadm/v1beta2#ClusterConfiguration
  cluster_name: my-cluster
