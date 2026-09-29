resource "google_service_account" "gke_nodes" {
  account_id   = "gke-hub-nodes"
  display_name = "GKE hub nodes"
  description  = "Node service account of the hub GKE cluster."

  depends_on = [google_project_service.this]
}

resource "google_container_cluster" "hub" {
  name     = "hub"
  location = var.zone

  network         = google_compute_network.hub.id
  subnetwork      = google_compute_subnetwork.hub.id
  networking_mode = "VPC_NATIVE"

  # Node pools are separate resources, but GKE cannot create a cluster without a default pool.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = true

  release_channel {
    channel = "REGULAR"
  }

  # With the HTTP load-balancing add-on disabled, Traefik's LoadBalancer Services need GKE 1.36 or later.
  min_master_version = "1.36"

  # Dataplane V2 (eBPF); it also enforces NetworkPolicy, so no network_policy block or addon.
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # No master_ipv4_cidr_block: the cluster uses Private Service Connect, not VPC peering (see README, "Firewall").
  private_cluster_config {
    enable_private_nodes = true
  }

  # Only the DNS-based endpoint (IAM-authenticated) is reachable; both IP-based endpoints are disabled.
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }

    ip_endpoints_config {
      enabled = false
    }
  }

  # Gateway API CRDs and Traefik are installed by Argo CD.
  gateway_api_config {
    channel = "CHANNEL_DISABLED"
  }

  # HTTP load balancing is GKE Ingress, which the hub doesn't use. Below GKE 1.36 it also backs the
  # backend-service-based load balancers of Traefik's LoadBalancer Services; min_master_version rules that out.
  addons_config {
    http_load_balancing {
      disabled = true
    }

    # Mounts the private arikkfir-docs bucket into the docs site.
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  enable_shielded_nodes = true

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = true
    }
  }

  # Fridays and Saturdays (the Israeli weekend), 00:00-08:00 UTC.
  maintenance_policy {
    recurring_window {
      start_time = "2026-01-02T00:00:00Z"
      end_time   = "2026-01-02T08:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=FR,SA"
    }
  }

  depends_on = [google_project_service.this]
}

resource "google_container_node_pool" "system" {
  name           = "system"
  cluster        = google_container_cluster.hub.name
  location       = google_container_cluster.hub.location
  node_locations = [var.zone]

  initial_node_count = 1

  autoscaling {
    total_min_node_count = var.system_pool.min_nodes
    total_max_node_count = var.system_pool.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.system_pool.machine_type
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      "kfirs.com/pool" = "system"
    }

    boot_disk {
      disk_type = "pd-balanced"
      size_gb   = 50
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # initial_node_count forces replacement and a manual resize changes it; never recreate the pool over it.
  lifecycle {
    ignore_changes = [initial_node_count]
  }

  depends_on = [google_project_iam_member.this]
}

resource "google_container_node_pool" "ci" {
  name           = "ci"
  cluster        = google_container_cluster.hub.name
  location       = google_container_cluster.hub.location
  node_locations = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]

  autoscaling {
    total_min_node_count = var.ci_pool.min_nodes
    total_max_node_count = var.ci_pool.max_nodes
    location_policy      = "ANY"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.ci_pool.machine_type
    image_type      = "COS_CONTAINERD"
    spot            = true
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      "kfirs.com/pool" = "ci"
    }

    # Only Tekton runs (via Tekton's default pod template) tolerate this.
    taint {
      key    = "kfirs.com/pool"
      value  = "ci"
      effect = "NO_SCHEDULE"
    }

    boot_disk {
      disk_type = "pd-balanced"
      size_gb   = 50
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_iam_member.this]
}
