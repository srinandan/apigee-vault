#!/bin/sh
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

helm repo add external-secrets https://external-secrets.github.io/kubernetes-external-secrets/
helm install external-secrets/kubernetes-external-secrets --generate-name --set env.VAULT_ADDR=http://vault.srinandans.internal:8200 --set serviceAccount.name=apigee --set serviceAccount.create=false