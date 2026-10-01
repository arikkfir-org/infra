locals {
  # checks: required status checks beyond Continuous Integration, which every repository requires.
  repositories = {
    ".github" = {
      description = "The organization's welcome page on GitHub."
      checks      = []
    }
    docs = {
      description = "Knowledge base of the development hub, published to the arikkfir-docs bucket."
      checks      = []
    }
    infra = {
      description = "Terraform for GitHub, GCP and the Argo CD bootstrap."
      checks      = []
    }
    delivery = {
      description = "Argo CD applications (GitOps) for the hub cluster."
      checks      = []
    }
    octomaton = {
      description = "CI orchestrator: a GitHub App that runs Tekton pipelines."
      checks      = []
    }
    tooling = {
      description = "Org-wide tooling: the Claude Code bundle, the pull request reviewer and the organization pipelines."
      checks      = []
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
  has_discussions = true

  allow_squash_merge          = true
  allow_merge_commit          = true
  allow_rebase_merge          = true
  allow_auto_merge            = true
  delete_branch_on_merge      = true
  allow_forking               = true
  allow_update_branch         = true
  archived                    = false
  merge_commit_title          = "PR_TITLE"
  merge_commit_message        = "PR_BODY"
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

# Dependabot alerts and security updates. Version updates need a dependabot.yml in the repository itself.
resource "github_repository_vulnerability_alerts" "this" {
  for_each = local.repositories

  repository = github_repository.this[each.key].name
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "this" {
  for_each = local.repositories

  # Security updates need the alerts enabled first.
  repository = github_repository_vulnerability_alerts.this[each.key].repository
  enabled    = true
}

resource "github_repository_autolink_reference" "linear" {
  for_each = local.repositories

  repository          = github_repository.this[each.key].name
  key_prefix          = "ENG-"
  target_url_template = "https://linear.app/arikkfir/issue/ENG-<num>"
  is_alphanumeric     = true
}
