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


gcloud kms keyrings create vault \
  --location global \
  --project ${PROJECT_ID}

gcloud kms keys create vault-init \
  --location global \
  --keyring vault \
  --purpose encryption \
  --project ${PROJECT_ID}

gsutil mb -p ${PROJECT_ID} gs://${GCS_BUCKET_NAME}

gcloud iam service-accounts create vault-server \
  --display-name "vault service account" \
  --project ${PROJECT_ID}

gsutil iam ch \
  serviceAccount:vault-server@${PROJECT_ID}.iam.gserviceaccount.com:objectAdmin \
  gs://${GCS_BUCKET_NAME}

gsutil iam ch \
  serviceAccount:vault-server@${PROJECT_ID}.iam.gserviceaccount.com:legacyBucketReader \
  gs://${GCS_BUCKET_NAME}

gcloud kms keys add-iam-policy-binding \
  vault-init \
  --location global \
  --keyring vault \
  --member serviceAccount:vault-server@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --project ${PROJECT_ID}

gcloud iam service-accounts keys create \ 
  client_secret.json --iam-account=vault-server@${PROJECT_ID}.iam.gserviceaccount.com
