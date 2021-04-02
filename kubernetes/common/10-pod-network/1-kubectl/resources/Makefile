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


BASE_URL = https://docs.projectcalico.org/archive/v3.18/manifests
BASE_MANIFESTS = calico.yaml calicoctl.yaml
MANIFESTS = $(BASE_MANIFESTS) calico.patched.yaml

all: $(MANIFESTS)

$(BASE_MANIFESTS):
	curl --output "$@" "$(BASE_URL)/$@"

# See https://github.com/kubernetes-sigs/kustomize/issues/680 for why this isn't
# done with kustomize.
calico.patched.yaml: calico.yaml calico.patch
	patch -o "$@" calico.yaml calico.patch
