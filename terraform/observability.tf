locals {
  exporter_metrics = [
    "cloudfunctions.googleapis.com/function/execution_count",
    "cloudtasks.googleapis.com/queue/depth",
    "run.googleapis.com/job/completed_execution_count",
    "run.googleapis.com/job/failed_execution_count",
    "run.googleapis.com/job/execution_latencies"
  ]
}

resource "google_storage_bucket_object" "exporter_config" {
  name   = ".env"
  bucket = google_storage_bucket.configs_bucket.name

  content = templatefile("${path.module}/templates/.env.tftpl", {
    project_id   = var.project_id
    metrics_list = join(",", local.exporter_metrics)
  })
}