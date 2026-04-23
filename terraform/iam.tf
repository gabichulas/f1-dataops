resource "google_service_account" "extractor_sa" {
  account_id   = "f1-extractor-sa"
  display_name = "F1 Data Extractor Service Account"
}

resource "google_service_account" "scheduler_sa" {
  account_id   = "f1-scheduler-sa"
  display_name = "Service Account for F1 Cloud Scheduler"
}

resource "google_service_account" "function_sa" {
  account_id   = "f1-scheduler-function-sa"
  display_name = "Service Account for F1 Scheduler Function"
}

resource "google_service_account" "vm_sa" {
  account_id   = "f1-vm-sa"
  display_name = "Service Account for F1 Observability VM"
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

resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
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

resource "google_storage_bucket_iam_member" "loki_storage_admin" {
  bucket = google_storage_bucket.loki_logs_storage.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_iam_workload_identity_pool" "wip" {
  workload_identity_pool_id = "${var.project_base_name}-wip"
  display_name              = "GITHUB-ACTIONS-WIP"
  description               = "Workload Identity Pool for GitHub Actions integration"
}

resource "google_iam_workload_identity_pool_provider" "wip_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.wip.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.project_base_name}-wip-provider"
  display_name                       = "${google_iam_workload_identity_pool.wip.display_name}-PROVIDER"
  description                        = "GitHub Actions identity pool provider"
  attribute_condition                = <<EOT
    attribute.repository == "gabichulas/f1-dataops" &&
    assertion.ref_type == "branch"
EOT
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}