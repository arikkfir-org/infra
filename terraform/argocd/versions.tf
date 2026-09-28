terraform {
  required_version = ">= 1.14"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  backend "gcs" {
    bucket = "arikkfir-tfstate"
    prefix = "argocd"
  }
}

provider "google" {
  project = var.project_id
}

# The cluster only exposes its DNS-based endpoint, which accepts Google OAuth access tokens (IAM) and serves a
# publicly trusted certificate (Google Trust Services), not one signed by the cluster CA. So no
# cluster_ca_certificate: setting it would replace the system trust store and fail TLS verification.
provider "helm" {
  kubernetes = {
    host  = "https://${local.cluster_endpoint}"
    token = data.google_client_config.current.access_token
  }
}
