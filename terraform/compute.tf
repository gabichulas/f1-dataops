resource "google_artifact_registry_repository" "f1_docker_repo" {
  location      = var.region
  repository_id = "${var.project_base_name}-repo"
  description   = "Docker repo"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent-only"
    action = "KEEP"

    most_recent_versions {
      keep_count = 2
    }
  }
}

resource "google_cloud_run_v2_job" "cloud_run" {
  name                = "${var.project_base_name}-cloud-run-job"
  location            = var.region
  deletion_protection = false

  template {
    template {
      service_account = google_service_account.extractor_sa.email

      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.f1_docker_repo.repository_id}/f1-extractor:v1"

        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.f1_data_lake.name
        }
      }
    }
  }
}

resource "google_cloudfunctions2_function" "scheduler_function" {
  name        = "${var.project_base_name}-scheduler-function"
  location    = var.region
  description = "F1 Task Scheduler Function"

  build_config {
    runtime     = "python311"
    entry_point = "schedule_f1_extractions"

    source {
      storage_source {
        bucket = google_storage_bucket.f1_metadata.name
        object = google_storage_bucket_object.scheduler_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256Mi"
    timeout_seconds       = 60
    service_account_email = google_service_account.function_sa.email

    environment_variables = {
      PROJECT_ID            = var.project_id
      REGION                = var.region
      BUCKET_NAME           = google_storage_bucket.f1_metadata.name
      QUEUE_NAME            = google_cloud_tasks_queue.f1_tasks.name
      JOB_NAME              = google_cloud_run_v2_job.cloud_run.name
      SERVICE_ACCOUNT_EMAIL = google_service_account.extractor_sa.email
    }
  }
}
