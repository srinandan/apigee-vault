# Sample using External Secrets

This sample explores the use of [External Secrets](https://www.godaddy.com/engineering/2019/04/16/kubernetes-external-secrets/) to create secrets automatically from a Secret provider like Vault (NOTE: External Secrets also support GCP, AWS and Azure Secrets). In this model, `External Secrets`, which has a customer Resource Definition (CRD) and a controller, automatically create (upserts) Kubernetes secrets. 

In this sample the controller integrates with the Vault installed previously.  

## Objective

Define a secret in Vault. Create an External Secret and have the External Secret controller create the necessary Kubernetes secrets. Then mount those secrets in a sample Deployment.

Step 1: Install External Secrets

```bash
./install-ext-secrets.sh
```

Step 2: Install sample application

This step has two critical parts:

* Create the ExternalSecret with the backend type set to `vault`. Note the role and KV version (defined in the previous steps)
* An `initContainer` to delay the startup/bootup of the application. This is to allow the controller create the secret before the pod starts.

___

## Support

This is not an officially supported Google product