# Sample using Vault Agent

This sample explores the use of the [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector). In this example, we inject secrets used by Apigee hybrid into a sample Deployment. The deployment is an alpine image (with a few utilities other installed)

## Objective

Define secrets in Vault and have those secrets injected to the Deployment (Pod) automatically

## Steps

Step 1: Create a policy

```bash
./create-apigee-policy.sh
```

NOTE: This is an overly permissive policy and is meant for illustrative purposes only.

Step 2: Create a role

```bash
./create-apigee-role.sh
```

This is a critical step. This binds a Kubernetes Service Account and a Kubernetes namespace with a role. The Pod must use the service account defined in this role to be able to get the secret.

NOTE: This tutorial assumes the customer has Apigee hybrid 1.4 or higher. With Apigee hybrid 1.4, each component has a Kubernetes Service Account. For example:

```bash
kubectl get sa -n apigee

NAME                                              SECRETS   AGE
apigee-cassandra-schema-setup-${ORG}-cb84b88-sa   1         xxd
apigee-cassandra-user-setup-${ORG}-cb84b88-sa     1         xxd
apigee-connect-agent-${ORG}-cb84b88-sa            1         xxd
apigee-init                                       1         xxd
apigee-mart-${ORG}-cb84b88-sa                     1         xxd
apigee-metrics-apigee-telemetry                   1         xxd
apigee-runtime-${ORG}-${ENV1}-1d0dc5e-sa          1         xxd
apigee-runtime-${ORG}-${ENV2}-8dd9313-sa          1         xxd
apigee-synchronizer-${ORG}-${ENV1}-1d0dc5e-sa     1         xxd
apigee-synchronizer-${ORG}-${ENV2}-8dd9313-sa     1         xxd
apigee-udca-${ORG}-${ENV1}-1d0dc5e-sa             1         xxd
apigee-udca-${ORG}-${ENV2}-8dd9313-sa             1         xxd
apigee-watcher-${ORG}-cb84b88                     1         xxd
```

In practice, users would map the namespace `apigee` (also user defined) and the service accounts listed here to the policies they create.

Step 3: Create a sample secret

In this sample, we will setup the secrets used by the Apigee runtime. There are 4 secrets:

* kmsEncryptionKey: This key is used to encrypt/decrpyt KMS entities like `client_secret`
* kvmEncryptionKey: This key is used to encrypt/decrpyt Org level KMV entities
* cacheEncryptionKey: This key is used to encrypt/decrpyt environment level Cache entries
* envKvmEncryptionKey: This key is used to encrypt/decrpyt environment level KMV values

In addition, this sample also requires users add two entries to the same secret with the ORG and ENV name.

* org: The Apigee hybrid org name
* env: The Apigee hybrid env name

```bash
./set-apigee-encrytpion.keys
```

Step 4: Install a sample application

There are three important parts to the Kubernetes manifest [client.yaml](./client.yaml).

* The service account section. This example uses a sample name like `apigee`. In practice, you'd skip this step since Apigee already defines service accounts
* Annotations: Define annotations for the Pod injector

  ```yaml
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "apigee-role"
        # setting this annotation so that the init container can execute the sh file
        vault.hashicorp.com/agent-init-first: "true"
        # the name 'prod1' should match the last leaf in the secret
        vault.hashicorp.com/agent-inject-secret-prod1: "secret/srinandans-hybrid/prod1"
        # Environment variable export template
        # the name 'prod1' should match the last leaf in the secret
        vault.hashicorp.com/agent-inject-template-prod1: |
          {{- with secret "secret/srinandans-hybrid/prod1?version=1" }}
            export {{ .Data.data.org }}_KMS_ENCRYPTION_KEY="{{ .Data.data.kmsEncryptionKey }}"
            export {{ .Data.data.org }}_KVM_ENCRYPTION_KEY="{{ .Data.data.kvmEncryptionKey }}"
            export {{ .Data.data.org }}_{{ .Data.data.env }}_CACHE_ENCRYPTION_KEY="{{ .Data.data.cacheEncryptionKey }}"
            export {{ .Data.data.org }}_{{ .Data.data.env }}_KVM_ENCRYPTION_KEY="{{ .Data.data.envKvmEncryptionKey }}"
          {{- end }}
  ```

* initContainer: At the time of writing this document, Vault injector does not actually create environment variables. Instead if generates a file (by default in `/vault/secrets/`) that contains the bash script to set environment variables. This open [issue](https://github.com/hashicorp/vault-k8s/issues/14) may solve this problem in the future. In the meanwhile, we will use an initContainer to execute the sh script.

  ```yaml
      initContainers:
        - name: init-env-vars
          image: busybox
          command: ["/bin/sh", "-c", "source /vault/secrets/*"]  
  ```

```bash
kubectl apply -f client.yaml
```

Testing the setup

```bash
kubectl exec -it -c client $(kubectl get pods --output=jsonpath={.items..metadata.name} -l app=apigee-demo | awk '{print $1}') -- sh -c env
```

You should see the environment names injected automatically

## Updating Secrets

At the time of writing this, managing of pods (restarting) when secrets are updated is left to the user. This [issue](https://github.com/hashicorp/vault-k8s/issues/196) when solve may provide an annotation to automatically restart the pod.

___

## Support

This is not an officially supported Google product