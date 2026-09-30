locals {
  # Databases on the hub's PostgreSQL instance. Their users and passwords are created by hand, like secret values.
  databases = toset([
    "grafana",
  ])
}

# The hub's PostgreSQL: a private address only (the peered range in network.tf), TLS required, reached in the cluster
# as postgres.hub.internal (dns.tf).
resource "google_sql_database_instance" "hub" {
  name                = "hub"
  region              = var.region
  database_version    = "POSTGRES_18"
  deletion_protection = true

  settings {
    # Shared-core tiers exist on the Enterprise edition only; PostgreSQL 16 and later default to Enterprise Plus.
    edition                     = "ENTERPRISE"
    tier                        = "db-f1-micro"
    availability_type           = "ZONAL"
    disk_type                   = "PD_SSD"
    disk_size                   = 10
    disk_autoresize             = true
    deletion_protection_enabled = true

    location_preference {
      zone = var.zone
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.hub.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled    = true
      start_time = "01:00"

      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day  = 7
      hour = 2
    }
  }

  depends_on = [google_service_networking_connection.peered_services]
}

resource "google_sql_database" "this" {
  for_each = local.databases

  name     = each.key
  instance = google_sql_database_instance.hub.name
}
