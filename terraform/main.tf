terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_service_account" "extractor_sa" {
  account_id   = "f1-extractor-sa"
  display_name = "F1 Data Extractor Service Account"
}

resource "google_storage_bucket_iam_member" "bucket_writer" {
  bucket = google_storage_bucket.f1_data_lake.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.extractor_sa.email}"
}

resource "google_artifact_registry_repository_iam_member" "repo_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.f1_docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.extractor_sa.email}"
}


resource "google_service_account" "scheduler_sa" {
  account_id   = "f1-scheduler-sa"
  display_name = "Service Account for F1 Cloud Scheduler"
}

resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

resource "google_cloud_tasks_queue" "f1_tasks" {
  name     = "${var.project_base_name}-tasks-queue"
  location = var.region

  rate_limits {
    max_dispatches_per_second = 1
    max_concurrent_dispatches = 5
  }

  retry_config {
    max_attempts = 3
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

    uri = google_cloudfunctions2_function.scheduler_function.service_config[0].uri
    oidc_token {
      service_account_email = google_service_account.scheduler_sa.email
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


resource "google_storage_bucket" "f1_data_lake" {
  name     = "${var.project_id}-${var.project_base_name}-data-lake"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket" "f1_metadata" {
  name     = "${var.project_id}-${var.project_base_name}-metadata"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true

}

resource "google_artifact_registry_repository" "f1_docker_repo" {
  location      = var.region
  repository_id = "${var.project_base_name}-repo"
  description   = "Docker repo"
  format        = "DOCKER"

  # Auto-cleanup to stay under 500MB free tier
  cleanup_policies {
    id     = "keep-recent-only"
    action = "KEEP"
    most_recent_versions {
      keep_count = 2
    }
  }
}



# ---------------------------- CLOUD FUNCTION --------------------------- #

data "archive_file" "scheduler_source" {
  type        = "zip"
  source_dir  = "${path.module}/functions/scheduler"
  output_path = "${path.module}/files/scheduler.zip"
}

resource "google_storage_bucket_object" "scheduler_zip" {
  name   = "scheduler-code${data.archive_file.scheduler_source.output_md5}.zip"
  bucket = google_storage_bucket.f1_metadata.name
  source = data.archive_file.scheduler_source.output_path
}

resource "google_service_account" "function_sa" {
  account_id   = "f1-scheduler-function-sa"
  display_name = "Service Account for F1 Scheduler Function"
}

resource "google_storage_bucket_iam_member" "calendar_reader" {
  bucket = google_storage_bucket.f1_metadata.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "task_enqueuer" {
  project = var.project_id
  role    = "roles/cloudtasks.enqueuer"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
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

data "google_project" "project" {}

resource "google_project_iam_member" "build_logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "build_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "build_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}