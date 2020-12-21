# Install vault

These instructions show how to install [vault](https://www.vaultproject.io/) from Hashicorp on GKE. This install uses GCS for storage and Cloud KMS to encrypt the seal. These intructions are not meant to be production grade, nor a tutorial of how to install vault. They mostly for illustrative purposes.

## Prerequisites

* A GKE cluster (test with GKE 1.17)
* A static IP address (this sample uses an private IP)
* Assumes the user is a project owner and can create various entities
* Helm 3.x 

## Steps

Step 0: Setup environment variables

```bash
export PROJECT_ID="my-project"
export GCS_BUCKET_NAME="${PROJECT_ID}-vault-storage"
export KMS_KEY_ID="projects/${PROJECT_ID}/locations/global/keyRings/vault/cryptoKeys/vault-init"
```

Step 1: Create the necessary GCS bucket, Cloud KMS Key ring etc.

```bash
./setup.sh
```

Step 2: Create secret
This secret gives vault the permissions to use GCS and Cloud KMS

```bash
./create-secret.sh
```

Step 3: Create ConfigMap
The configmap has the configuration needed for vault to startup

```bash
./create-configmap.sh
```

Step 4: Install vault

```bash
kubectl apply -f vault.yaml
```

Step 5: Setup vault

```bash
./setup-vault.sh
```

Step 6: Install Vault Injector

```bash
./install-injector.sh
```

___

## Support

This is not an officially supported Google product