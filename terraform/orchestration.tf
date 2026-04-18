resource "google_cloud_tasks_queue" "f1_tasks" {
  name     = "${var.project_base_name}-tasks-queue"
  location = var.region

  rate_limits {
    max_dispatches_per_second = 1
    max_concurrent_dispatches = 5
  }

  retry_config {
    max_attempts       = 3
    max_retry_duration = "3600s"
  }
}

resource "google_cloud_scheduler_job" "weekly_planner" {
  name        = "${var.project_base_name}-weekly-planner"
  description = "Triggers the F1 pipeline planner every Monday at 9 AM"
  schedule    = "0 9 * * 1"
  time_zone   = "UTC"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.scheduler_function.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }
}
