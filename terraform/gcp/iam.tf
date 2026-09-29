locals {
  # Kubernetes workloads authenticate with GKE Workload Identity Federation; IAM grants go straight to the
  # Kubernetes ServiceAccount principal (no Google service accounts to impersonate).
  k8s_principal_prefix = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject"

  principals = {
    external_secrets = "${local.k8s_principal_prefix}/ns/external-secrets/sa/external-secrets"
    cert_manager     = "${local.k8s_principal_prefix}/ns/cert-manager/sa/cert-manager"
    grafana          = "${local.k8s_principal_prefix}/ns/grafana/sa/grafana"
    docs             = "${local.k8s_principal_prefix}/ns/docs/sa/docs"
    octomaton        = "${local.k8s_principal_prefix}/ns/octomaton/sa/octomaton"
    ci_docs          = "${local.k8s_principal_prefix}/ns/ci-docs/sa/pipeline"
    ci_tooling       = "${local.k8s_principal_prefix}/ns/ci-tooling/sa/pipeline"
    ci_octomaton     = "${local.k8s_principal_prefix}/ns/ci-octomaton/sa/pipeline"
    gke_nodes        = google_service_account.gke_nodes.member
  }

  project_iam = {
    "grafana/monitoring.viewer"                     = { role = "roles/monitoring.viewer", member = local.principals.grafana }
    "octomaton/telemetry.metricsWriter"             = { role = "roles/telemetry.metricsWriter", member = local.principals.octomaton }
    "octomaton/telemetry.tracesWriter"              = { role = "roles/telemetry.tracesWriter", member = local.principals.octomaton }
    "octomaton/serviceusage.serviceUsageConsumer"   = { role = "roles/serviceusage.serviceUsageConsumer", member = local.principals.octomaton }
    "gke-nodes/container.defaultNodeServiceAccount" = { role = "roles/container.defaultNodeServiceAccount", member = local.principals.gke_nodes }
  }

  bucket_iam = {
    "arikkfir-docs/docs/storage.objectViewer"               = { bucket = "arikkfir-docs", role = "roles/storage.objectViewer", member = local.principals.docs }
    "arikkfir-docs/ci-docs/storage.objectUser"              = { bucket = "arikkfir-docs", role = "roles/storage.objectUser", member = local.principals.ci_docs }
    "arikkfir-docs/ci-docs/storage.legacyBucketReader"      = { bucket = "arikkfir-docs", role = "roles/storage.legacyBucketReader", member = local.principals.ci_docs }
    "arikkfir-claude/allUsers/storage.legacyObjectReader"   = { bucket = "arikkfir-claude", role = "roles/storage.legacyObjectReader", member = "allUsers" }
    "arikkfir-claude/ci-tooling/storage.objectUser"         = { bucket = "arikkfir-claude", role = "roles/storage.objectUser", member = local.principals.ci_tooling }
    "arikkfir-claude/ci-tooling/storage.legacyBucketReader" = { bucket = "arikkfir-claude", role = "roles/storage.legacyBucketReader", member = local.principals.ci_tooling }
  }

  images_iam = {
    "ci-octomaton/artifactregistry.writer" = { role = "roles/artifactregistry.writer", member = local.principals.ci_octomaton }
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

  bucket = google_storage_bucket.this[each.value.bucket].name
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

# Zone-scoped, so cert-manager cannot list zones: its Cloud DNS solvers must name the zone (hostedZoneName).
resource "google_dns_managed_zone_iam_member" "cert_manager" {
  for_each = toset([local.hub_zone, "octomaton-dev"])

  managed_zone = google_dns_managed_zone.this[each.key].name
  role         = "roles/dns.admin"
  member       = local.principals.cert_manager
}

# The grant on the hub zone predates for_each. Remove once applied.
moved {
  from = google_dns_managed_zone_iam_member.cert_manager
  to   = google_dns_managed_zone_iam_member.cert_manager["kfirs-com"]
}
