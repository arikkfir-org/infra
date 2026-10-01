resource "github_repository_ruleset" "default-branch" {
  for_each = local.repositories

  name        = "Default branch"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Lets a solo maintainer merge a pull request without a second reviewer.
  # OrganizationAdmin takes no actor_id (the API ignores it and the provider docs say to leave it unset).
  bypass_actors {
    actor_type  = "OrganizationAdmin"
    bypass_mode = "always"
  }

  # Role 5 is the built-in repository admin role.
  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
      allowed_merge_methods             = ["merge"]
    }

    # No integration_id: any source may report a required check.
    required_status_checks {
      strict_required_status_checks_policy = false

      dynamic "required_check" {
        for_each = toset(concat(["Continuous Integration"], each.value.checks))

        content {
          context = required_check.value
        }
      }
    }

    merge_queue {
      merge_method                      = "MERGE"
      grouping_strategy                 = "ALLGREEN"
      max_entries_to_build              = 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
    }
  }
}
