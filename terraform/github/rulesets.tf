resource "github_repository_ruleset" "protected" {
  for_each = { for name, repo in local.repositories : name => repo if repo.protected }

  name        = "default-branch"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Lets a solo maintainer merge a pull request without a second reviewer; direct pushes stay blocked.
  # OrganizationAdmin takes no actor_id (the API ignores it and the provider docs say to leave it unset).
  bypass_actors {
    actor_type  = "OrganizationAdmin"
    bypass_mode = "pull_request"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      required_review_thread_resolution = true
      allowed_merge_methods             = ["squash"]
    }

    required_status_checks {
      strict_required_status_checks_policy = false

      required_check {
        context        = "ci"
        integration_id = var.octomatron_app_id
      }
    }

    merge_queue {
      merge_method                      = "SQUASH"
      grouping_strategy                 = "ALLGREEN"
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 5
      check_response_timeout_minutes    = 60
    }
  }
}

resource "github_repository_ruleset" "direct_push" {
  for_each = { for name, repo in local.repositories : name => repo if !repo.protected }

  name        = "default-branch"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true
  }
}
