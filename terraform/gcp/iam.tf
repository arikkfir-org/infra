locals {
  # Kubernetes workloads authenticate with GKE Workload Identity Federation; IAM grants go straight to the
  # Kubernetes ServiceAccount principal (no Google service accounts to impersonate).
  k8s_principal_prefix = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject"

  principals = {
    external_secrets = "${local.k8s_principal_prefix}/ns/external-secrets/sa/external-secrets"
    cert_manager     = "${local.k8s_principal_prefix}/ns/cert-manager/sa/cert-manager"
    grafana          = "${local.k8s_principal_prefix}/ns/grafana/sa/grafana"
    ci_docs          = "${local.k8s_principal_prefix}/ns/ci-docs/sa/pipeline"
    ci_tooling       = "${local.k8s_principal_prefix}/ns/ci-tooling/sa/pipeline"
    ci_octomaron     = "${local.k8s_principal_prefix}/ns/ci-octomaron/sa/pipeline"
    gke_nodes        = google_service_account.gke_nodes.member
  }

  project_iam = {
    "grafana/monitoring.viewer"                     = { role = "roles/monitoring.viewer", member = local.principals.grafana }
    "gke-nodes/container.defaultNodeServiceAccount" = { role = "roles/container.defaultNodeServiceAccount", member = local.principals.gke_nodes }
  }

  bucket_iam = {
    "arikkfir-docs/allUsers/storage.legacyObjectReader"     = { bucket = "arikkfir-docs", role = "roles/storage.legacyObjectReader", member = "allUsers" }
    "arikkfir-docs/ci-docs/storage.objectUser"              = { bucket = "arikkfir-docs", role = "roles/storage.objectUser", member = local.principals.ci_docs }
    "arikkfir-docs/ci-docs/storage.legacyBucketReader"      = { bucket = "arikkfir-docs", role = "roles/storage.legacyBucketReader", member = local.principals.ci_docs }
    "arikkfir-claude/allUsers/storage.legacyObjectReader"   = { bucket = "arikkfir-claude", role = "roles/storage.legacyObjectReader", member = "allUsers" }
    "arikkfir-claude/ci-tooling/storage.objectUser"         = { bucket = "arikkfir-claude", role = "roles/storage.objectUser", member = local.principals.ci_tooling }
    "arikkfir-claude/ci-tooling/storage.legacyBucketReader" = { bucket = "arikkfir-claude", role = "roles/storage.legacyBucketReader", member = local.principals.ci_tooling }
  }

  images_iam = {
    "ci-octomaron/artifactregistry.writer" = { role = "roles/artifactregistry.writer", member = local.principals.ci_octomaron }
    "gke-nodes/artifactregistry.reader"    = { role = "roles/artifactregistry.reader", member = local.principals.gke_nodes }
  }
}

resource "google_project_iam_member" "this" {
  for_each = local.project_iam

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

resource "google_storage_bucket_iam_member" "this" {
  for_each = local.bucket_iam

  bucket = google_storage_bucket.public[each.value.bucket].name
  role   = each.value.role
  member = each.value.member
}

resource "google_artifact_registry_repository_iam_member" "images" {
  for_each = local.images_iam

  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = each.value.role
  member     = each.value.member
}

resource "google_secret_manager_secret_iam_member" "external_secrets" {
  for_each = google_secret_manager_secret.this

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.principals.external_secrets
}

# Zone-scoped, so cert-manager cannot list zones: its Cloud DNS solver must name the zone (hostedZoneName).
resource "google_dns_managed_zone_iam_member" "cert_manager" {
  managed_zone = google_dns_managed_zone.this[local.hub_zone].name
  role         = "roles/dns.admin"
  member       = local.principals.cert_manager
}
