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

resource "google_storage_bucket_object" "scheduler_zip" {
  name   = "scheduler-code${data.archive_file.scheduler_source.output_md5}.zip"
  bucket = google_storage_bucket.f1_metadata.name
  source = data.archive_file.scheduler_source.output_path
}
