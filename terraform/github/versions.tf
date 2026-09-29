terraform {
  required_version = ">= 1.14"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  backend "gcs" {
    bucket = "arikkfir-tfstate"
    prefix = "github"
  }
}

# Authenticates with the GITHUB_TOKEN environment variable (see README for the required permissions).
provider "github" {
  owner = "arikkfir-org"
}
