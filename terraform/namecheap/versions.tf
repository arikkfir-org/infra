terraform {
  required_version = ">= 1.14"

  required_providers {
    namecheap = {
      source  = "namecheap/namecheap"
      version = "~> 2.9"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }

  backend "gcs" {
    bucket = "arikkfir-devops"
    prefix = "namecheap"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Authenticates with NAMECHEAP_USER_NAME, NAMECHEAP_API_USER and NAMECHEAP_API_KEY. Namecheap admits only the IPs on the
# account's allow-list: the hub's egress address, which every call from the cluster leaves through.
provider "namecheap" {
  client_ip = data.google_compute_address.egress.address
}
