resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "images"
  format        = "DOCKER"
  description   = "Container images built by the hub CI."

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "14d"
    }
  }

  # KEEP wins over DELETE: the 20 newest versions of each image survive even when untagged.
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 20
    }
  }

  depends_on = [google_project_service.this]
}

# Pull requests' preview images: any branch's CI may push here, so production never pulls from it. A preview needs its
# images only while its pull request is open.
resource "google_artifact_registry_repository" "previews" {
  location      = var.region
  repository_id = "previews"
  format        = "DOCKER"
  description   = "Container images of pull requests' previews, built by the hub CI from any branch."

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"

    condition {
      tag_state  = "ANY"
      older_than = "14d"
    }
  }

  # KEEP wins over DELETE: the 20 newest versions of each image survive, so a quiet pull request's preview still pulls.
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 20
    }
  }

  depends_on = [google_project_service.this]
}

# Octomaton's releases, which anyone who runs Octomaton pulls (allUsers read, iam.tf): octomaton and octomaton-logs,
# tagged with the commit's short SHA and main. Only its release pipeline writes here, from main. The hub's own
# images, Fin's included, stay in images, which stays private.
resource "google_artifact_registry_repository" "octomaton" {
  location      = var.region
  repository_id = "octomaton"
  format        = "DOCKER"
  description   = "Octomaton's releases, built from its main and pulled by every installation."

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "14d"
    }
  }

  # KEEP wins over DELETE: the 20 newest versions of each image survive even when untagged.
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 20
    }
  }

  depends_on = [google_project_service.this]
}
