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

resource "google_storage_bucket" "f1-data-lake" {
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