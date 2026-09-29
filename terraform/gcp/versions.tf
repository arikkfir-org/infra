terraform {
  required_version = ">= 1.14"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.4"
    }
  }

  backend "gcs" {
    bucket = "arikkfir-devops"
    prefix = "gcp"
  }
}

# No default_labels: they would add labels to the imported DNS zones and break a no-change import.
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
