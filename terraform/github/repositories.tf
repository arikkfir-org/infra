locals {
  # protected = true: default branch changes only through a reviewed pull request and the merge queue.
  # protected = false: direct pushes to the default branch are allowed (deletion and force-push are not).
  repositories = {
    ".github" = {
      description                       = "Organization profile and org-wide GitHub defaults."
      protected                         = true
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
    }
    docs = {
      description                       = "Knowledge base of the development hub, published to the arikkfir-docs bucket."
      protected                         = true
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
    }
    infra = {
      description                       = "Terraform for GitHub, GCP and the Argo CD bootstrap."
      protected                         = true
      max_entries_to_build              = 1
      min_entries_to_merge              = 1
      max_entries_to_merge              = 1
      min_entries_to_merge_wait_minutes = 0
      check_response_timeout_minutes    = 60
    }
    delivery = {
      description                       = "Argo CD applications (GitOps) for the hub cluster."
      protected                         = true
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
    }
    octomaton = {
      description                       = "CI orchestrator: a GitHub App that runs Tekton pipelines."
      protected                         = true
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
    }
    tooling = {
      description                       = "Claude Code web bundle."
      protected                         = true
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
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
