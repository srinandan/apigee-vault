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

# The format used for the KV name is secret/{orgname}/{environment name}. Users may choose to split this further with 
# secret/{orgname}/{environment name}/runtime, secret/{orgname}/cassandra and so on
# It is important to add the org name env name inside the secret also. This will be used later.
# NOTE: Since org and env names cannot have a - in them, org and env names must be converted to _ (underscore). 
# Also convert them uppercase
vault kv put secret/srinandans-hybid/prod1 cacheEncryptionKey="aWxvdmVhcGlzMTIzNDU2Nw==" envKvmEncryptionKey="aWxvdmVhcGlzMTIzNDU2Nw==" kmsEncryptionKey="aWxvdmVhcGlzMTIzNDU2Nw==" kvmEncryptionKey="aWxvdmVhcGlzMTIzNDU2Nw==" org=$ORG env=$ENV


