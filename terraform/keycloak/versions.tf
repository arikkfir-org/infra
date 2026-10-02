terraform {
  required_version = ">= 1.14"

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.9"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  backend "gcs" {
    bucket = "arikkfir-devops"
    prefix = "keycloak"
  }
}

# Authenticates with KEYCLOAK_CLIENT_ID and KEYCLOAK_CLIENT_SECRET: a service account in the master realm.
provider "keycloak" {
  url = var.keycloak_url
}

provider "google" {
  project = var.project_id
}
