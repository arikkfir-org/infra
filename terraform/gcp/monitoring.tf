locals {
  # cobranch.app's alerts, on the metrics Managed Service for Prometheus scrapes from its servers
  # (docs/infra/designs/cobranch-app.md, "Monitoring"). Each is a PromQL expression over namespace cobranch-app that
  # returns a series while it should fire, held for duration. A ratio or percentile fires only over enough samples in
  # its window, so that one slow view or one failed request on a quiet installation emails nobody.
  cobranch_app_alerts = {
    "cobranch-app-console-pages-slow" = {
      display_name = "cobranch.app: Console pages slow"
      duration     = "900s"
      query        = "histogram_quantile(0.95, sum by (le, cobranch_console_page) (rate(cobranch_console_page_duration_seconds_bucket{namespace=\"cobranch-app\", cobranch_console_navigation=\"route\"}[15m]))) > 3 and on (cobranch_console_page) sum by (cobranch_console_page) (increase(cobranch_console_page_duration_seconds_count{namespace=\"cobranch-app\", cobranch_console_navigation=\"route\"}[15m])) >= 10"
      content      = "The 95th percentile of a Console page's views, moves inside the Console, has been over 3 seconds for 15 minutes, over at least 10 views. Dashboard Cobranch in Grafana shows which page, and whether its Git reads or its routes take the time."
    }
    "cobranch-app-server-errors" = {
      display_name = "cobranch.app: server errors"
      duration     = "600s"
      query        = "sum by (service_name) (rate(http_server_request_duration_seconds_count{namespace=\"cobranch-app\", http_response_status_code=~\"5..\"}[10m])) / sum by (service_name) (rate(http_server_request_duration_seconds_count{namespace=\"cobranch-app\"}[10m])) > 0.05 and on (service_name) sum by (service_name) (increase(http_server_request_duration_seconds_count{namespace=\"cobranch-app\"}[10m])) >= 20"
      content      = "Over 5% of a Cobranch server's answers have been 5xx for 10 minutes, over at least 20 answers. Its logs in namespace cobranch-app name each failure."
    }
    "cobranch-app-apis-slow" = {
      display_name = "cobranch.app: APIs slow"
      duration     = "900s"
      query        = "histogram_quantile(0.95, sum by (le, service_name) (rate(http_server_request_duration_seconds_bucket{namespace=\"cobranch-app\", service_name=~\"rest-server|graphql-server\"}[15m]))) > 2 and on (service_name) sum by (service_name) (increase(http_server_request_duration_seconds_count{namespace=\"cobranch-app\", service_name=~\"rest-server|graphql-server\"}[15m])) >= 20"
      content      = "The 95th percentile of the REST or GraphQL server's answers has been over 2 seconds for 15 minutes, over at least 20 answers. Dashboard Cobranch in Grafana shows which routes."
    }
    "cobranch-app-workspaces-slow" = {
      display_name = "cobranch.app: throwaway repositories slow"
      duration     = "900s"
      query        = "histogram_quantile(0.95, sum by (le) (rate(cobranch_git_workspace_duration_seconds_bucket{namespace=\"cobranch-app\"}[15m]))) > 2 and sum(increase(cobranch_git_workspace_duration_seconds_count{namespace=\"cobranch-app\"}[15m])) >= 10"
      content      = "The 95th percentile of the Git server's throwaway repositories has taken over 2 seconds to build for 15 minutes, over at least 10 of them: every code read, clone, fetch and push waits on it."
    }
    "cobranch-app-pack-cache-missing" = {
      display_name = "cobranch.app: pack cache missing"
      duration     = "1800s"
      query        = "sum(rate(cobranch_git_pack_cache_lookups_total{namespace=\"cobranch-app\", cobranch_git_pack_cache_result=\"miss\"}[30m])) / sum(rate(cobranch_git_pack_cache_lookups_total{namespace=\"cobranch-app\"}[30m])) > 0.5 and sum(increase(cobranch_git_pack_cache_lookups_total{namespace=\"cobranch-app\"}[30m])) >= 20"
      content      = "Under half the packs the Git server's throwaway repositories link have been in its cache for 30 minutes, over at least 20 lookups, so most reads download their packs from the database. Compare the cache's usage with its limit on dashboard Cobranch; gitServer.cache.size raises it."
    }
    "cobranch-app-metrics-gone" = {
      display_name = "cobranch.app: metrics gone"
      duration     = "600s"
      query        = "absent_over_time(target_info{namespace=\"cobranch-app\"}[5m])"
      content      = "No Cobranch server of cobranch.app has been scraped for 15 minutes: the servers are down, or PodMonitoring cobranch or NetworkPolicy cobranch-metrics no longer lets the collectors reach them."
    }
  }
}

# The owner's email, which every alert of this root notifies.
resource "google_monitoring_notification_channel" "owner" {
  display_name = "The owner, by email"
  type         = "email"
  labels = {
    email_address = "arikkfir@gmail.com"
  }
}

resource "google_monitoring_alert_policy" "cobranch_app" {
  for_each = local.cobranch_app_alerts

  display_name          = each.value.display_name
  combiner              = "OR"
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.owner.id]
  user_labels = {
    installation = "cobranch-app"
  }

  conditions {
    display_name = each.value.display_name

    condition_prometheus_query_language {
      query               = each.value.query
      duration            = each.value.duration
      evaluation_interval = "60s"
      # The series exist only once the servers have been scraped, which may come after this apply.
      disable_metric_validation = true
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    subject   = each.value.display_name
    content   = each.value.content
    mime_type = "text/markdown"
  }
}
