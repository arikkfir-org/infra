data "google_client_config" "current" {}

data "google_container_cluster" "hub" {
  name     = var.cluster_name
  location = var.cluster_location
}

locals {
  cluster_endpoint = data.google_container_cluster.hub.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}
