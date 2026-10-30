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
# tagged with the commit's short SHA, and every version, tagged vX.Y.Z (the same images, retagged). Only its
# pipelines main and tag write here, from main and from v* tags. The hub's own images, Fin's included, stay in images, which stays private.
resource "google_artifact_registry_repository" "octomaton" {
  location      = var.region
  repository_id = "octomaton"
  format        = "DOCKER"
  description   = "Octomaton's releases, built from its main and its versions, and pulled by every installation."

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

# DevHub's releases, which anyone who installs DevHub pulls (allUsers read, iam.tf): devhub and devhub-console, tagged
# with the commit's short SHA, and every version, tagged X.Y.Z (the same images, retagged), with Helm chart charts/devhub
# at that version. Only devhub's pipelines main and tag write here, from main and from v* tags. The hub's demo
# installation runs main's.
resource "google_artifact_registry_repository" "devhub" {
  location      = var.region
  repository_id = "devhub"
  format        = "DOCKER"
  description   = "DevHub's releases, built from its main and its versions, and pulled by every installation."

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

# DevHub's pull requests' preview images: devhub and devhub-console of each pushed head commit, tagged with its short SHA,
# which only DevHub's previews pull. Not previews: devhub is public and its pull requests' CI runs Dependabot's
# dependency code, so a writer there could replace Fin's preview images. Not devhub, whose main and release tags every
# installation pulls. A preview needs its images only while its pull request is open.
resource "google_artifact_registry_repository" "devhub_previews" {
  location      = var.region
  repository_id = "devhub-previews"
  format        = "DOCKER"
  description   = "Container images of DevHub's pull requests' previews, built by its CI from any branch."

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

# Cobranch's releases, DevHub's under its new name, which anyone who installs Cobranch pulls (allUsers read, iam.tf):
# cobranch and cobranch-console, tagged with the commit's short SHA, and every version, tagged X.Y.Z (the same images,
# retagged), with Helm chart charts/cobranch at that version. Only cobranch's pipelines main and tag write here, from
# main and from v* tags. The hub's demo installation runs main's. devhub keeps DevHub's 0.0.1 as published.
resource "google_artifact_registry_repository" "cobranch" {
  location      = var.region
  repository_id = "cobranch"
  format        = "DOCKER"
  description   = "Cobranch's releases, built from its main and its versions, and pulled by every installation."

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

# Cobranch's pull requests' preview images: cobranch and cobranch-console of each pushed head commit, tagged with its
# short SHA, which only Cobranch's previews pull, for the reasons devhub-previews exists.
resource "google_artifact_registry_repository" "cobranch_previews" {
  location      = var.region
  repository_id = "cobranch-previews"
  format        = "DOCKER"
  description   = "Container images of Cobranch's pull requests' previews, built by its CI from any branch."

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
