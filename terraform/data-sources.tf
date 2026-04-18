data "archive_file" "scheduler_source" {
  type        = "zip"
  source_dir  = "${path.module}/functions/scheduler"
  output_path = "${path.module}/files/scheduler.zip"
}

data "google_project" "project" {}
