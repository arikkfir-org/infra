resource "google_compute_network" "hub" {
  name                    = "hub"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.this]
}

resource "google_compute_subnetwork" "hub" {
  name                     = "hub"
  region                   = var.region
  network                  = google_compute_network.hub.id
  ip_cidr_range            = var.cidrs.nodes
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.cidrs.pods
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.cidrs.services
  }
}

resource "google_compute_router" "hub" {
  name    = "hub"
  region  = var.region
  network = google_compute_network.hub.id
}

# Egress for the private nodes (and their Pods).
resource "google_compute_router_nat" "hub" {
  name                               = "hub"
  region                             = var.region
  router                             = google_compute_router.hub.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Load balancer IPs of the two Traefik entry-point pairs (see dns.tf for the hosts they serve).
resource "google_compute_address" "ingress" {
  for_each = toset(["protected", "public"])

  name         = "ingress-${each.key}"
  description  = "Traefik ${each.key} load balancer"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  depends_on = [google_project_service.this]
}
