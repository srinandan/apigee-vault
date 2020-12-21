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

kubectl creat configmap vault --from-literal api-addr=https://${VAULT_LOAD_BALANCER_IP}:8200 --from-literal gcs-bucket-name=${GCS_BUCKET_NAME} --from-literal kms-key-id=${KMS_KEY_ID} --from-literal project-id=${PROJECT_ID} --from-literal key-ring=${KEY_RING} --from-literal region=${REGION} --from-literal crypto-key=${CRYPTO_KEY}
