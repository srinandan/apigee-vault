terraform {
  required_version = ">= 0.12"
}

variable "region" {
  type        = string
  default     = "us-west1"
  description = "Region in which to create the cluster and run Vault."
}

variable "zone" {
  type        = string
  default     = "us-west1-a"
  description = "Zone in which to create the cluster and run Vault."
}

variable "project" {
  type        = string
  default     = "srinandans-apigee"
  description = "Project ID where Terraform is authenticated to run to create additional projects. If provided, Terraform will create the GKE and Vault cluster inside this project. If not given, Terraform will generate a new project."
}

variable "kubernetes_secrets_crypto_key" {
  type        = string
  default     = "kubernetes-secrets"
  description = "Name of the KMS key to use for encrypting the Kubernetes database."
}

variable "project_services" {
  type = list(string)
  default = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
  description = "List of services to enable on the project."
}

variable "storage_iam_roles" {
  type = list(string)
  default = [
    "roles/storage.legacyBucketReader",
    "roles/storage.objectAdmin",
  ]
  description = "List of iam roles."
}

variable "crypto_iam_roles" {
  type = list(string)
  default = [
    "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  ]
  description = "List of iam roles."
}

#
# GKE options
# ------------------------------

variable "kubernetes_cluster_name" {
  type        = string
  default     = "vault"
  description = "Default GKE Cluster Name"
}

variable "kubernetes_instance_type" {
  type        = string
  default     = "e2-standard-4"
  description = "Instance type to use for the nodes."
}

variable "kubernetes_release_channel" {
  type    = string
  default = "REGULAR"
}

variable "kubernetes_logging_service" {
  type        = string
  default     = "logging.googleapis.com/kubernetes"
  description = "Name of the logging service to use. By default this uses the new Stackdriver GKE beta."
}

variable "kubernetes_monitoring_service" {
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
  description = "Name of the monitoring service to use. By default this uses the new Stackdriver GKE beta."
}

variable "kubernetes_min_nodes" {
  type        = number
  default     = 3
  description = "Minimum number of nodes to deploy in a zone of the Kubernetes cluster."
}

variable "kubernetes_max_nodes" {
  type        = number
  default     = 6
  description = "Maximum number of nodes to deploy in a zone of the Kubernetes cluster."
}

variable "kubernetes_disk_size" {
  type        = number
  default     = 25
  description = "Boot disk size for Kubernetes nodes"
}

variable "vault_sa" {
  type        = string
  default     = "vault-sa"
  description = "Vault Pod Service Account Name"
}

variable "vault_google_sa" {
  type        = string
  default     = "srinandans-apigee-vault-sa"
  description = "Vault Pod Service Account Name"
}

variable "kubernetes_masters_ipv4_cidr" {
  type        = string
  default     = "172.16.0.32/28"
  description = "IP CIDR block for the Kubernetes master nodes. This must be exactly /28 and cannot overlap with any other IP CIDR ranges."  
}

#
# KMS options
# ------------------------------

variable "kms_key_ring" {
  type        = string
  default     = "vault"
  description = "String value to use for the name of the KMS key ring. This exists for backwards-compatability for users of the existing configurations. Please use kms_key_ring_prefix instead."
}

variable "kms_crypto_key" {
  type        = string
  default     = "vault-init"
  description = "String value to use for the name of the KMS crypto key."
}

#
# Vault options
# ------------------------------

variable "num_vault_pods" {
  type        = number
  default     = 2
  description = "Number of Vault pods to run. Anti-affinity rules spread pods across available nodes. Please use an odd number for better availability."
}

variable "vault_container" {
  type        = string
  default     = "vault:1.6.1"
  description = "Name of the Vault container image to deploy. This can be specified like \"container:version\" or as a full container URL."
}

variable "vault_init_container" {
  type        = string
  default     = "busybox:latest"
  description = "Name of the Vault init container image to deploy. This can be specified like \"container:version\" or as a full container URL."
}

variable "vault_image_url" {
  type        = string
  default     = "gcr.io"  
  description = "Default container repo"
}

variable "vault_namespace" {
  type        = string
  default     = "default"  
  description = "Namespace where vault should be installed"  
}

#
# Load Balancer options
# --------------------------------
variable "internal_load_balancer" {
  type        = bool
  default     = false
  description = "Use internal load balancer. An internal IP address will be created. Service annotations are required for GCE."
}

variable "internal_address" {
  type        = string
  default     = "10.138.0.3"  
  description = "Internal IP Address for vault in the us-west1 region"
}

variable "service_annotations" {
  type    = map
  default = {}
  description = "Annotations for the vault service. For an GCE internal load balancer specify {\"cloud.google.com/load-balancer-type\" = \"Internal\"}"
}