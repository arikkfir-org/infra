locals {
  # Kubernetes workloads authenticate with GKE Workload Identity Federation; IAM grants go straight to the
  # Kubernetes ServiceAccount principal (no Google service accounts to impersonate).
  k8s_principal_prefix = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject"

  principals = {
    external_secrets     = "${local.k8s_principal_prefix}/ns/external-secrets/sa/external-secrets"
    cert_manager         = "${local.k8s_principal_prefix}/ns/cert-manager/sa/cert-manager"
    grafana              = "${local.k8s_principal_prefix}/ns/grafana/sa/grafana"
    docs                 = "${local.k8s_principal_prefix}/ns/docs/sa/docs"
    octomaton            = "${local.k8s_principal_prefix}/ns/octomaton/sa/octomaton"
    ci_tooling_publish   = "${local.k8s_principal_prefix}/ns/ci-tooling/sa/ci-tooling-publish"
    ci_octomaton_release = "${local.k8s_principal_prefix}/ns/ci-octomaton/sa/ci-octomaton-release"
    ci_fin_preview       = "${local.k8s_principal_prefix}/ns/ci-fin/sa/ci-fin-preview"
    ci_fin_release       = "${local.k8s_principal_prefix}/ns/ci-fin/sa/ci-fin-release"
    ci_fin_ci            = "${local.k8s_principal_prefix}/ns/ci-fin/sa/ci-fin-ci"
    ci_infra_plan        = "${local.k8s_principal_prefix}/ns/ci-infra/sa/ci-infra-plan"
    ci_infra_apply       = "${local.k8s_principal_prefix}/ns/ci-infra/sa/ci-infra-apply"
    gke_nodes            = google_service_account.gke_nodes.member
    claude_code          = google_service_account.claude_code.member
    fin_api              = "${local.k8s_principal_prefix}/ns/fin/sa/api"
    fin_worker           = "${local.k8s_principal_prefix}/ns/fin/sa/worker"
    fin_scraper          = "${local.k8s_principal_prefix}/ns/fin/sa/scraper"
    # Every pod of a Fin pull request's environment that presents its projected token (pool fin-pull-requests below).
    fin_pull_requests = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.fin_pull_requests.name}/*"
  }

  project_iam = {
    "grafana/monitoring.viewer"                     = { role = "roles/monitoring.viewer", member = local.principals.grafana }
    "octomaton/telemetry.metricsWriter"             = { role = "roles/telemetry.metricsWriter", member = local.principals.octomaton }
    "octomaton/telemetry.tracesWriter"              = { role = "roles/telemetry.tracesWriter", member = local.principals.octomaton }
    "octomaton/serviceusage.serviceUsageConsumer"   = { role = "roles/serviceusage.serviceUsageConsumer", member = local.principals.octomaton }
    "gke-nodes/container.defaultNodeServiceAccount" = { role = "roles/container.defaultNodeServiceAccount", member = local.principals.gke_nodes }

    # Fin: production's workloads, and every pull request's environment through pool fin-pull-requests. Traces and
    # metrics from all of them; model calls (Claude and Gemini on Vertex AI) from fin-worker only.
    "fin-api/telemetry.tracesWriter"                      = { role = "roles/telemetry.tracesWriter", member = local.principals.fin_api }
    "fin-api/telemetry.metricsWriter"                     = { role = "roles/telemetry.metricsWriter", member = local.principals.fin_api }
    "fin-api/serviceusage.serviceUsageConsumer"           = { role = "roles/serviceusage.serviceUsageConsumer", member = local.principals.fin_api }
    "fin-worker/telemetry.tracesWriter"                   = { role = "roles/telemetry.tracesWriter", member = local.principals.fin_worker }
    "fin-worker/telemetry.metricsWriter"                  = { role = "roles/telemetry.metricsWriter", member = local.principals.fin_worker }
    "fin-worker/serviceusage.serviceUsageConsumer"        = { role = "roles/serviceusage.serviceUsageConsumer", member = local.principals.fin_worker }
    "fin-worker/aiplatform.user"                          = { role = "roles/aiplatform.user", member = local.principals.fin_worker }
    "fin-scraper/telemetry.tracesWriter"                  = { role = "roles/telemetry.tracesWriter", member = local.principals.fin_scraper }
    "fin-scraper/telemetry.metricsWriter"                 = { role = "roles/telemetry.metricsWriter", member = local.principals.fin_scraper }
    "fin-scraper/serviceusage.serviceUsageConsumer"       = { role = "roles/serviceusage.serviceUsageConsumer", member = local.principals.fin_scraper }
    "fin-pull-requests/telemetry.tracesWriter"            = { role = "roles/telemetry.tracesWriter", member = local.principals.fin_pull_requests }
    "fin-pull-requests/telemetry.metricsWriter"           = { role = "roles/telemetry.metricsWriter", member = local.principals.fin_pull_requests }
    "fin-pull-requests/serviceusage.serviceUsageConsumer" = { role = "roles/serviceusage.serviceUsageConsumer", member = local.principals.fin_pull_requests }
    "fin-pull-requests/aiplatform.user"                   = { role = "roles/aiplatform.user", member = local.principals.fin_pull_requests }

    # Claude Code's cloud sessions read the hub cluster's objects and pod logs through GKE's MCP server
    # (container.googleapis.com/mcp), with the viewer role of google_project_iam_member.claude_code.
    "claude-code/mcp.toolUser" = { role = "roles/mcp.toolUser", member = local.principals.claude_code }

    # infra's plans: read access to everything terraform/gcp manages. iam.securityReviewer reads every IAM policy, the
    # buckets', DNS zones' and repository's included.
    "ci-infra-plan/iam.securityReviewer"            = { role = "roles/iam.securityReviewer", member = local.principals.ci_infra_plan }
    "ci-infra-plan/serviceusage.serviceUsageViewer" = { role = "roles/serviceusage.serviceUsageViewer", member = local.principals.ci_infra_plan }
    "ci-infra-plan/compute.networkViewer"           = { role = "roles/compute.networkViewer", member = local.principals.ci_infra_plan }
    "ci-infra-plan/container.clusterViewer"         = { role = "roles/container.clusterViewer", member = local.principals.ci_infra_plan }
    "ci-infra-plan/artifactregistry.reader"         = { role = "roles/artifactregistry.reader", member = local.principals.ci_infra_plan }
    "ci-infra-plan/secretmanager.viewer"            = { role = "roles/secretmanager.viewer", member = local.principals.ci_infra_plan }
    "ci-infra-plan/dns.reader"                      = { role = "roles/dns.reader", member = local.principals.ci_infra_plan }
    "ci-infra-plan/iam.serviceAccountViewer"        = { role = "roles/iam.serviceAccountViewer", member = local.principals.ci_infra_plan }
    "ci-infra-plan/iam.workloadIdentityPoolViewer"  = { role = "roles/iam.workloadIdentityPoolViewer", member = local.principals.ci_infra_plan }

    # infra's applies, on merges to main only (Octomaton enforces the ServiceAccount's octomaton.dev/branches). Owner
    # can't go to a federated principal; securityAdmin sets every IAM policy here, the DNS zones' included.
    "ci-infra-apply/serviceusage.serviceUsageAdmin" = { role = "roles/serviceusage.serviceUsageAdmin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/compute.networkAdmin"           = { role = "roles/compute.networkAdmin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/container.admin"                = { role = "roles/container.admin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/artifactregistry.admin"         = { role = "roles/artifactregistry.admin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/storage.admin"                  = { role = "roles/storage.admin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/secretmanager.admin"            = { role = "roles/secretmanager.admin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/dns.admin"                      = { role = "roles/dns.admin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/iam.serviceAccountAdmin"        = { role = "roles/iam.serviceAccountAdmin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/iam.securityAdmin"              = { role = "roles/iam.securityAdmin", member = local.principals.ci_infra_apply }
    "ci-infra-apply/iam.workloadIdentityPoolAdmin"  = { role = "roles/iam.workloadIdentityPoolAdmin", member = local.principals.ci_infra_apply }
  }

  # Every repository with a CI tenant publishes its docs to its own layer of arikkfir-docs, .layers/<repository>/ (see
  # the reference, "Docs site").
  docs_layers = toset(["delivery", "docs", "fin", "infra", "octomaton", "tooling"])

  # The docs site's pipelines list the bucket's object names: docs-reader on pull requests, docs-publisher on main.
  docs_listers = merge([
    for repository in local.docs_layers : {
      for sa in ["docs-reader", "docs-publisher"] :
      "arikkfir-docs/ci-${repository}/${sa}/storage.legacyBucketReader" => {
        bucket = "arikkfir-docs"
        role   = "roles/storage.legacyBucketReader"
        member = "${local.k8s_principal_prefix}/ns/ci-${repository}/sa/${sa}"
      }
    }
  ]...)

  bucket_iam = merge(local.docs_listers, {
    "arikkfir-docs/docs/storage.objectViewer"             = { bucket = "arikkfir-docs", role = "roles/storage.objectViewer", member = local.principals.docs }
    "arikkfir-claude/allUsers/storage.legacyObjectReader" = { bucket = "arikkfir-claude", role = "roles/storage.legacyObjectReader", member = "allUsers" }
    # tooling's publish pipeline, on main only (the ServiceAccount's octomaton.dev/branches).
    "arikkfir-claude/ci-tooling-publish/storage.objectUser"         = { bucket = "arikkfir-claude", role = "roles/storage.objectUser", member = local.principals.ci_tooling_publish }
    "arikkfir-claude/ci-tooling-publish/storage.legacyBucketReader" = { bucket = "arikkfir-claude", role = "roles/storage.legacyBucketReader", member = local.principals.ci_tooling_publish }
    # Fin's scrape artifacts: the scraper writes what fin-api serves and fin-worker re-ingests, and may not read them back
    # (traces keep the typed read-only passwords). Pull requests share one bucket, under a prefix each.
    "arikkfir-fin/fin-scraper/storage.objectCreator"                  = { bucket = "arikkfir-fin", role = "roles/storage.objectCreator", member = local.principals.fin_scraper }
    "arikkfir-fin/fin-api/storage.objectViewer"                       = { bucket = "arikkfir-fin", role = "roles/storage.objectViewer", member = local.principals.fin_api }
    "arikkfir-fin/fin-worker/storage.objectViewer"                    = { bucket = "arikkfir-fin", role = "roles/storage.objectViewer", member = local.principals.fin_worker }
    "arikkfir-fin-pull-requests/fin-pull-requests/storage.objectUser" = { bucket = "arikkfir-fin-pull-requests", role = "roles/storage.objectUser", member = local.principals.fin_pull_requests }
    # Fin's CI cache: its release pipeline, on main only, restores and saves it; ci and preview restore it, from any
    # branch. It holds nothing secret.
    "arikkfir-fin-ci-cache/ci-fin-release/storage.objectUser"   = { bucket = "arikkfir-fin-ci-cache", role = "roles/storage.objectUser", member = local.principals.ci_fin_release }
    "arikkfir-fin-ci-cache/ci-fin-ci/storage.objectViewer"      = { bucket = "arikkfir-fin-ci-cache", role = "roles/storage.objectViewer", member = local.principals.ci_fin_ci }
    "arikkfir-fin-ci-cache/ci-fin-preview/storage.objectViewer" = { bucket = "arikkfir-fin-ci-cache", role = "roles/storage.objectViewer", member = local.principals.ci_fin_preview }
  })

  images_iam = {
    # octomaton's and fin's release pipelines, on main only (the ServiceAccounts' octomaton.dev/branches).
    "ci-octomaton-release/artifactregistry.writer" = { role = "roles/artifactregistry.writer", member = local.principals.ci_octomaton_release }
    "ci-fin-release/artifactregistry.writer"       = { role = "roles/artifactregistry.writer", member = local.principals.ci_fin_release }
    "gke-nodes/artifactregistry.reader"            = { role = "roles/artifactregistry.reader", member = local.principals.gke_nodes }
  }

  previews_iam = {
    # fin's preview pipeline, from any branch: what it pushes runs only in previews.
    "ci-fin-preview/artifactregistry.writer" = { role = "roles/artifactregistry.writer", member = local.principals.ci_fin_preview }
    "gke-nodes/artifactregistry.reader"      = { role = "roles/artifactregistry.reader", member = local.principals.gke_nodes }
  }
}

resource "google_project_iam_member" "this" {
  for_each = local.project_iam

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# Claude Code's cloud sessions' identity; their environment holds its key, made by hand. The account and its viewer role
# predate their management here (imports.tf).
resource "google_service_account" "claude_code" {
  account_id   = "claude-code"
  display_name = "claude-code"
  description  = "Claude Code web sessions."

  lifecycle {
    prevent_destroy = true
  }
}

# Claude Code's cloud sessions look around the project. viewer reads no Kubernetes Secret or Secret Manager payload, and
# changes nothing.
resource "google_project_iam_member" "claude_code" {
  project = var.project_id
  role    = "roles/viewer"
  member  = local.principals.claude_code

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket_iam_member" "this" {
  for_each = local.bucket_iam

  bucket = google_storage_bucket.this[each.value.bucket].name
  role   = each.value.role
  member = each.value.member
}

# Each repository's docs-publisher, on main only (its octomaton.dev/branches), writes its own layer and nothing else.
resource "google_storage_bucket_iam_member" "docs_publisher" {
  for_each = local.docs_layers

  bucket = google_storage_bucket.this["arikkfir-docs"].name
  role   = "roles/storage.objectUser"
  member = "${local.k8s_principal_prefix}/ns/ci-${each.key}/sa/docs-publisher"

  condition {
    title      = "layer-${each.key}"
    expression = "resource.name.startsWith(\"projects/_/buckets/arikkfir-docs/objects/.layers/${each.key}/\")"
  }
}

# Fin's CI uploads each run's end-to-end report under .reports/fin/, from any branch, since pull requests' runs need
# theirs too: ci-fin-ci may create objects there and nowhere else, and can't change or delete them (see the reference,
# "Docs site").
resource "google_storage_bucket_iam_member" "ci_reports" {
  for_each = { fin = local.principals.ci_fin_ci }

  bucket = google_storage_bucket.this["arikkfir-docs"].name
  role   = "roles/storage.objectCreator"
  member = each.value

  condition {
    title      = "reports-${each.key}"
    expression = "resource.name.startsWith(\"projects/_/buckets/arikkfir-docs/objects/.reports/${each.key}/\")"
  }
}

# infra's plans read each bucket's settings.
resource "google_storage_bucket_iam_member" "ci_infra_plan" {
  for_each = google_storage_bucket.this

  bucket = each.value.name
  role   = "roles/storage.legacyBucketReader"
  member = local.principals.ci_infra_plan
}

# Terraform's state bucket, created by hand. Plans read the state without taking the lock; applies write it through
# roles/storage.admin.
resource "google_storage_bucket_iam_member" "state" {
  bucket = "arikkfir-devops"
  role   = "roles/storage.objectViewer"
  member = local.principals.ci_infra_plan
}

resource "google_artifact_registry_repository_iam_member" "images" {
  for_each = local.images_iam

  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = each.value.role
  member     = each.value.member
}

resource "google_artifact_registry_repository_iam_member" "previews" {
  for_each = local.previews_iam

  location   = google_artifact_registry_repository.previews.location
  repository = google_artifact_registry_repository.previews.name
  role       = each.value.role
  member     = each.value.member
}

resource "google_secret_manager_secret_iam_member" "external_secrets" {
  for_each = { for id, secret in google_secret_manager_secret.this : id => secret if !contains(local.pipeline_secrets, id) }

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.principals.external_secrets
}

# infra's plans read their GitHub token and Keycloak credential at run time; applies read theirs through
# roles/secretmanager.admin.
resource "google_secret_manager_secret_iam_member" "ci_infra_plan" {
  for_each = toset(["infra-plan-github-pat", "infra-plan-keycloak-secret"])

  secret_id = google_secret_manager_secret.this[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.principals.ci_infra_plan
}

# The grant on the GitHub token predates for_each. Remove once applied.
moved {
  from = google_secret_manager_secret_iam_member.ci_infra_plan
  to   = google_secret_manager_secret_iam_member.ci_infra_plan["infra-plan-github-pat"]
}

# Applies create node pools that run as gke-hub-nodes@.
resource "google_service_account_iam_member" "gke_nodes" {
  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.principals.ci_infra_apply
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

# Fin's pull requests' environments come and go with the pull requests, and GKE's own pool grants only to namespaces named
# in advance. This pool trusts the hub cluster's ServiceAccount tokens from namespaces named fin-pr-* only: a pod there
# presents a projected token of the provider's audience through an external_account credential file.
resource "google_iam_workload_identity_pool" "fin_pull_requests" {
  workload_identity_pool_id = "fin-pull-requests"
  display_name              = "Fin pull requests"
  description               = "Pods of Fin's pull requests' environments (namespaces fin-pr-*)."

  depends_on = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "gke_hub" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.fin_pull_requests.workload_identity_pool_id
  workload_identity_pool_provider_id = "gke-hub"
  display_name                       = "GKE cluster hub"
  description                        = "ServiceAccount tokens of the hub cluster, from namespaces fin-pr-* only."

  attribute_mapping = {
    "google.subject"      = "assertion.sub"
    "attribute.namespace" = "assertion['kubernetes.io']['namespace']"
  }
  attribute_condition = "assertion['kubernetes.io']['namespace'].startsWith('fin-pr-')"

  oidc {
    # The cluster's ServiceAccount token issuer, whose keys GKE publishes. No allowed_audiences: tokens must name the
    # provider itself.
    issuer_uri = "https://container.googleapis.com/v1/projects/${var.project_id}/locations/${google_container_cluster.hub.location}/clusters/${google_container_cluster.hub.name}"
  }
}
