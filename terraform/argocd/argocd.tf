locals {
  argo_helm_repository = "https://argoproj.github.io/argo-helm"
}

# Bootstrap only. After the first sync, Argo CD manages itself through the `argocd` Application in
# arikkfir-org/delivery (same chart, same release name, so it adopts these resources). Argo CD applies manifests
# directly and never updates this Helm release record, so Terraform ignores all changes: it installs Argo CD on a
# cluster that lacks the release and otherwise never upgrades or reverts what Argo CD deployed.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = local.argo_helm_repository
  chart            = "argo-cd"
  version          = "10.9.2"
  timeout          = 600

  # Mirrors the self-managed values where it matters at bootstrap; in particular Dex stays off, so no bootstrap-only
  # Dex resources are left behind when Argo CD takes over (it does not prune what the self-managed values omit).
  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    dex = {
      enabled = false
    }
  })]

  lifecycle {
    ignore_changes = all
  }
}

# App of apps: syncs everything under apps/ in arikkfir-org/delivery, including Argo CD itself.
resource "helm_release" "root" {
  name       = "root"
  namespace  = "argocd"
  repository = local.argo_helm_repository
  chart      = "argocd-apps"
  version    = "2.0.5"

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = "https://github.com/arikkfir-org/delivery"
          targetRevision = "main"
          path           = "apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          # Child Applications gate the waves through their health; retry instead of stalling on a transient failure.
          retry = {
            limit = 10
            backoff = {
              duration    = "10s"
              factor      = 2
              maxDuration = "5m"
            }
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
