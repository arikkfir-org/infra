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
# Namecheap counts the account's 20 requests a minute across every run at once: a quarter each leaves room for four
# plans and applies, and a refused call's retries, 10 s to a minute apart, outlast a one-minute window, as the
# provider's guide for CI sets.
provider "namecheap" {
  client_ip           = data.google_compute_address.egress.address
  requests_per_minute = 5
  max_retries         = 5
  retry_base_delay    = "10s"
  retry_max_delay     = "60s"
  retry_max_elapsed   = "8m"
}
