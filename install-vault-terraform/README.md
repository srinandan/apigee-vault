# Install Vault via Terraform

This repo shows an example of installing Vault on GKE using Terraform. 

## Prerequisites

* Create a Google Service Account (the convention used in the script is $PROJECT-vault-sa) for Vault
  * No need to create a key for this service. No permissions are necessary (this will be done via Terraform)
* Create a Google Service Account for Terraform. 
  * Create and download the private key for this SA. Set the path to the private key in the env variable `GOOGLE_APPLICATION_CREDENTIALS`
  * Ensure this service account has:
    * roles/editor - Editor - All viewer permissions, plus permissions for actions that modify state, such as changing existing resources
    * roles/cloudkms.admin - Cloud KMS Admin - Provides full access to Cloud KMS resources, except encrypt and decrypt operations.
    * roles/iam. serviceAccountAdmin - Service Account Admin - Includes permissions to list service accounts and get details about a service account. Also includes permissions to create, update, and delete service accounts.
* Upload Vault docker images to your GCR repo (this is necessary since we are creating a private cluster)
  * Vault Image

    ```bash
    export PROJECT_ID=my-project
    export VAULT_VERSION=1.6.1
    docker pull vault:$VAULT_VERSION && docker tag vault:$VAULT_VERSION gcr.io/$PROJECT_ID/vault:$VAULT_VERSION && docker push gcr.io/$PROJECT_ID/vault:$VAULT_VERSION 
    ```

  * Vault Init Image (busybox)

    ```bash
    export PROJECT_ID=my-project
    docker pull busybox && docker tag busybox:latest gcr.io/$PROJECT_ID/busybox:latest && docker push gcr.io/$PROJECT_ID/busybox:latest
    ```
* Update variables in this [file](./variables.tf)
  * project
  * region


## Install

1. Initialize Terraform providers

```bash
terraform init
```

2. Validate Terraform

```bash
terraform validate
```

3. Create a plan

```bash
terraform plan
```

4. Apply the apply

```bash
terraform apply
```

5. Initalize Vault

  a. Exec to the pod:

  ```bash
  kubectl exec -it -c vault vault-0 -- sh
  ```

  b. Initialize Vault

  ```bash
  export VAULT_ADDR=https://127.0.0.1:8200
  vault operator init
  ```

Vault is now ready to use. Note the `Initial Root Token` this will be necessary to access vault.

## Operations

The terraform script does request a static ip, but does **not** create a DNS entry for it. It is recommended that one creates a DNS entry for the static ip.

Create a jump host VM to operate Vault.
