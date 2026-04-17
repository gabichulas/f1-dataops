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
  role = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.extractor_sa.email}"
}

resource "google_artifact_registry_repository_iam_member" "repo_reader" {
  project = var.project_id
  location = var.region
  repository = google_artifact_registry_repository.f1_docker_repo.name
  role = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.extractor_sa.email}"
}

resource "google_cloud_run_v2_job" "cloud_run" {
  name = "${var.project_base_name}_cloud_run_job"
  location = var.region

  template {
    template {
      service_account = google_service_account.extractor_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.f1_docker_repo.repository_id}/f1-extractor"
        env {
          name = "BUCKET_NAME"
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