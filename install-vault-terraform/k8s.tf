# Query the client configuration for our current service account, which should
# have permission to talk to the GKE cluster since it created it.
data "google_client_config" "current" {}

# This file contains all the interactions with Kubernetes
provider "kubernetes" {
  load_config_file = false
  host             = "https://${google_container_cluster.vault.endpoint}"

  cluster_ca_certificate = base64decode(
    google_container_cluster.vault.master_auth[0].cluster_ca_certificate,
  )
  token = data.google_client_config.current.access_token
  #config_context = ""
}

# Create a ConfigMap to store all the details for Vault to bootup 
resource "kubernetes_config_map" "vault" {
  metadata {
    name      = "vault"
    namespace = var.vault_namespace
  }

  data = {
    api-addr         = join("",["http://", var.internal_address, ":8200"])
    gcs-bucket-name  = google_storage_bucket.vault.name
    kms-key-id       = "projects/${var.project}/locations/${var.region}/keyRings/${var.kms_key_ring}/cryptoKeys/${var.kms_crypto_key}"
    project-id       = var.project
    key-ring         = var.kms_key_ring
    region           = var.region
    crypto-key       = var.kms_crypto_key
  }

  depends_on = [ google_compute_address.internal_address, google_kms_crypto_key.vault-init ]
}

# Create a Kubernetes Service Account and Annotate for Workload Identity
resource "kubernetes_service_account" "vault-sa" {
  metadata {
    name      = var.vault_sa
    namespace = var.vault_namespace
    annotations = {
        "iam.gke.io/gcp-service-account" = join("", [var.vault_google_sa, "@", var.project, ".iam.gserviceaccount.com"])
    }    
  }
  secret {
    name = var.vault_sa
  }  
  automount_service_account_token = true
}

resource "kubernetes_secret" "vault-sa" {
  metadata {
    name      = var.vault_sa
    namespace = var.vault_namespace
  }
}

# Create a Kubernetes Service with a static internal IP address (previously obtained)
resource "kubernetes_service" "vault-lb" {
  metadata {
    name      = "vault"
    namespace = var.vault_namespace
    labels = {
      app = "vault"
    }
    annotations = {
        "cloud.google.com/load-balancer-type" = "internal"
        "networking.gke.io/internal-load-balancer-allow-global-access" = "true" 
    }
  }

  spec {
    type                        = "LoadBalancer"
    load_balancer_ip            = google_compute_address.internal_address.address
    # Since Vault is setup as a stateful set, there can only be 1 pod per node
    external_traffic_policy     = "Local"

    selector = {
      app = "vault"
    }

    port {
      name        = "http"
      port        = 8200
    }

    port {
      name        = "server"
      port        = 8201
    }

  }
}

# Create a Stateful Set for Vault
resource "kubernetes_stateful_set" "vault" {
  metadata {
    name      = "vault"
    namespace = var.vault_namespace
    labels = {
      app = "vault"
    }
  }

  spec {
    service_name = "vault"

    replicas      = var.kubernetes_min_nodes

    selector {
      match_labels = {
        app = "vault"
      }
    }

    template {
      metadata {
        labels = {
          app = "vault"
        }
      }

      spec {
        termination_grace_period_seconds = 10

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 50

              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"

                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["vault"]
                  }
                }
              }
            }
          }
        }

        service_account_name = var.vault_sa

        init_container {
          name              = "vault-init"
          image             = join("/", [var.vault_image_url, var.project, var.vault_init_container])
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c"]
          args = [
              "cat > /etc/vault/config/vault.hcl <<EOF\nlistener \"tcp\" {\n  address = \"0.0.0.0:8200\"\n  tls_disable = \"true\"\n}\n\nstorage \"gcs\" {\n  bucket = \"$${GCS_BUCKET_NAME}\"\n  ha_enabled = \"true\"\n}\n\nseal \"gcpckms\" {\n  project     = \"$${PROJECT_ID}\"\n  region      = \"$${REGION}\"\n  key_ring    = \"$${KEY_RING}\"\n  crypto_key  = \"$${CRYPTO_KEY}\"\n}\n\ndisable_mlock = true\nui = false\n\nEOF\n"
          ]

          resources {
            requests {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          env {
            name  = "PROJECT_ID"
            value = var.project
          }          

          env {
            name  = "GCS_BUCKET_NAME"
            value = google_storage_bucket.vault.name
          }

          env {
            name  = "KMS_KEY"
            value = google_kms_key_ring.vault.name
          }

          env {
            name  = "REGION"
            value = google_kms_key_ring.vault.location
          }          

          env {
            name  = "CRYPTO_KEY"
            value = google_kms_crypto_key.vault-init.name
          }

          volume_mount {
            name       = "vault-config"
            mount_path = "/etc/vault/config"
          }                  
        }

        container {
          name              = "vault"
          image             = join("/", [var.vault_image_url, var.project, var.vault_container])
          image_pull_policy = "IfNotPresent"

          args = ["server", "-config=/etc/vault/config/vault.hcl"]

          security_context {
            capabilities {
              add = ["IPC_LOCK"]
            }
          }

          port {
            name           = "http"
            container_port = 8200
            protocol       = "TCP"
          }

          port {
            name           = "server"
            container_port = 8201
            protocol       = "TCP"
          }

          env {
            name  = "VAULT_API_ADDR"
            value_from {
                config_map_key_ref {
                    name = "vault"
                    key  = "api-addr"
                }
            }
          }

          env {
            name = "POD_IP_ADDR"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }          

          env {
            name  = "VAULT_GCPCKMS_SEAL_KEY_RING"
            value = google_kms_key_ring.vault.name
          }

          env {
            name  = "GOOGLE_PROJECT"
            value = var.project
          }

          env {
            name  = "GOOGLE_REGION"
            value = google_kms_key_ring.vault.location
          }          

          env {
            name  = "VAULT_GCPCKMS_SEAL_CRYPTO_KEY"
            value = google_kms_crypto_key.vault-init.name
          }          

          volume_mount {
            name       = "vault-config"
            mount_path = "/etc/vault/config"
          }
        }
        
        volume {
          name = "vault-config"
          empty_dir {}
        }        
      }      
    }
  }
}