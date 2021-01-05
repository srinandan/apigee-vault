// Configure the Google Cloud provider
provider "google" {
 project     = var.project
 region      = var.region
}

provider "google-beta" {
  region  = var.region
  project = var.project
}

# This service account was created out of band. It is being used here.
data "google_service_account" "vault-sa" {
   account_id = var.vault_google_sa
   project    = var.project
}

# This is the default compute engine service. Since the private cluster is 
# using the default service account, we are going to import the SA
data "google_project" "project" {}

# Enable required services on the project
resource "google_project_service" "service" {
  count   = length(var.project_services)
  project = var.project
  service = element(var.project_services, count.index)

  # Do not disable the service on destroy. On destroy, we are going to
  # destroy the project, but we need the APIs available to destroy the
  # underlying resources.
  disable_on_destroy = false
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = var.kms_key_ring
  location = var.region
  project  = var.project

  depends_on = [google_project_service.service]
}

# Create the crypto key for encrypting init keys
resource "google_kms_crypto_key" "vault-init" {
  name            = var.kms_crypto_key
  key_ring        = google_kms_key_ring.vault.id
  rotation_period = "604800s"
  lifecycle {
    prevent_destroy = true
  }
}

# Create the storage bucket
resource "google_storage_bucket" "vault" {
  name          = join("", [var.project, "-vault-storage"])
  project       = var.project
  force_destroy = true
  storage_class = "MULTI_REGIONAL"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = 1
    }
  }

  depends_on = [google_project_service.service]
}

# Grant service account access to the storage bucket
resource "google_storage_bucket_iam_member" "vault-server" {
  count  = length(var.storage_iam_roles)
  bucket = google_storage_bucket.vault.name
  role   = element(var.storage_iam_roles, count.index)
  member = "serviceAccount:${join("", [var.vault_google_sa, "@", var.project, ".iam.gserviceaccount.com"])}"   
}

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "vault-init" {
  count         = length(var.crypto_iam_roles)
  crypto_key_id = google_kms_crypto_key.vault-init.id
  role          = element(var.crypto_iam_roles, count.index)
  member        = "serviceAccount:${join("", [var.vault_google_sa, "@", var.project, ".iam.gserviceaccount.com"])}"
}

# Grant service account access to workload Identity user
resource "google_service_account_iam_binding" "wid-iam-role" {
  service_account_id = data.google_service_account.vault-sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    join("", ["serviceAccount:", var.project, ".svc.id.goog[", var.vault_namespace, "/", var.vault_sa, "]"])
  ]
}

# Grant service account access to crypto key for GKE database encryption
resource "google_kms_crypto_key_iam_member" "gke-database" {
  count         = length(var.crypto_iam_roles)
  crypto_key_id = google_kms_crypto_key.vault-init.id
  role          = element(var.crypto_iam_roles, count.index)
  member        = "serviceAccount:${join("", ["service-", data.google_project.project.number, "@container-engine-robot.iam.gserviceaccount.com"])}"  
}

# Grant service account access to key ring
resource "google_kms_key_ring_iam_binding" "vault" {
  count       = length(var.crypto_iam_roles)
  key_ring_id = google_kms_key_ring.vault.id
  role        = element(var.crypto_iam_roles, count.index)
  
  members = [
    "serviceAccount:${join("", [var.vault_google_sa, "@", var.project, ".iam.gserviceaccount.com"])}"
  ]
}

# Create the GKE cluster
resource "google_container_cluster" "vault" {

  provider = google-beta

  name     = var.kubernetes_cluster_name
  project  = var.project
  location = var.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.kubernetes_release_channel
  }

  logging_service    = var.kubernetes_logging_service
  monitoring_service = var.kubernetes_monitoring_service

  # Disable legacy ACLs. The default is false, but explicitly marking it false
  # here as well.
  enable_legacy_abac = false

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.vault-init.id
  }

  node_config {
    machine_type    = var.kubernetes_instance_type
    image_type      = "COS_CONTAINERD"
    service_account = "default"


    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Set metadata on the VM to supply more entropy
    metadata = {
      disable-legacy-endpoints         = "true"
    }

    labels = {
      service = "vault"
    }

    tags = ["vault"]

    # Protect node metadata
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  # Enable workload identity
  workload_identity_config {
    identity_namespace = join("", [var.project, ".svc.id.goog"])
  }  

  # Configure various addons
  addons_config {
    # Do not enable network policy configurations (like Calico).
    network_policy_config {
      disabled = true
    }
  }

  # Enables IP Aliasing - required for private clusters
  networking_mode = "VPC_NATIVE"

  # Allocate IPs in our subnetwork
  ip_allocation_policy {
    # The IP address range for the cluster pod IPs. Set to blank to have a range chosen with the default size
    cluster_ipv4_cidr_block = ""
    # The IP address range of the services IPs in this cluster. Set to blank to have a range chosen with the default size
    services_ipv4_cidr_block = ""
  }  

  # Disable basic authentication and cert-based authentication.
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Enable network policy configurations (like Calico) - for some reason this
  # has to be in here twice.
  network_policy {
    enabled = true
  }


  # Configure the cluster to be private (not have public facing IPs)
  private_cluster_config {
    # This field is misleading. This prevents access to the master API from
    # any external IP. While that might represent the most secure
    # configuration, it is not ideal for most setups. As such, we disable the
    # private endpoint (allow the public endpoint) and restrict which CIDRs
    # can talk to that endpoint.
    enable_private_endpoint = false

    enable_private_nodes   = true

    master_ipv4_cidr_block = var.kubernetes_masters_ipv4_cidr

    master_global_access_config {
      enabled = true
    }
  }

  depends_on = [
    google_project_service.service,
    google_kms_crypto_key_iam_member.vault-init,
    google_kms_crypto_key_iam_member.gke-database,
    google_storage_bucket_iam_member.vault-server,
  ]
}

# Create node pool for vault
resource "google_container_node_pool" "vault_preemptible_nodes" {
  name       = "vault-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.vault.name
  node_count = var.kubernetes_min_nodes

  autoscaling {
    min_node_count = var.kubernetes_min_nodes
    max_node_count = var.kubernetes_min_nodes
  }

  node_config {
    image_type      = "COS_CONTAINERD"
    preemptible     = true
    machine_type    = var.kubernetes_instance_type
    disk_size_gb    = var.kubernetes_disk_size
    service_account = "default"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      service = "vault"
    }

    tags = ["vault"]

    # Protect node metadata
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }

  }
  
  lifecycle {
    ignore_changes = [initial_node_count]
  }  
}

# Obtain a private IP Address
resource "google_compute_address" "internal_address" {
  name         = "vault-address"
  address_type = "INTERNAL"
  address      = var.internal_address
  region       = var.region
  subnetwork   = "default"
}
