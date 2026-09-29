locals {
  # protected = true: default branch changes only through a reviewed pull request and the merge queue.
  # protected = false: direct pushes to the default branch are allowed (deletion and force-push are not).
  repositories = {
    ".github" = {
      description = "Organization profile and org-wide GitHub defaults."
      protected   = true
    }
    docs = {
      description = "Knowledge base of the development hub, published to the arikkfir-docs bucket."
      protected   = false
    }
    infra = {
      description = "Terraform for GitHub, GCP and the Argo CD bootstrap."
      protected   = true
    }
    delivery = {
      description = "Argo CD applications (GitOps) for the hub cluster."
      protected   = true
    }
    octomatron = {
      description = "CI orchestrator: a GitHub App that runs Tekton pipelines."
      protected   = true
    }
    tooling = {
      description = "Claude Code web bundle."
      protected   = true
    }
  }
}

resource "github_repository" "this" {
  for_each = local.repositories

  name        = each.key
  description = each.value.description
  visibility  = "public"

  has_issues      = false
  has_projects    = false
  has_wiki        = false
  has_discussions = false

  allow_squash_merge          = true
  allow_merge_commit          = true
  allow_rebase_merge          = true
  allow_auto_merge            = true
  delete_branch_on_merge      = true
  allow_forking               = true
  allow_update_branch         = true
  archived                    = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

# Replaces the deprecated github_repository.vulnerability_alerts argument.
resource "github_repository_vulnerability_alerts" "this" {
  for_each = github_repository.this

  repository = each.value.name
  enabled    = true
}
