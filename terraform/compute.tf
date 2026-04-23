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
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.f1_docker_repo.repository_id}/f1-extractor:${var.extractor_image_tag}"

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

resource "google_compute_instance" "obs_vm" {
  name         = "${var.project_base_name}-obs-vm"
  machine_type = "e2-medium"
  zone         = "${var.region}-a"

  tags = ["grafana-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 15
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    mkdir -p /opt/observability
    chmod 777 /opt/observability

    mkdir -p /opt/observability/prometheus
    mkdir -p /opt/observability/loki

    gsutil cp gs://f1-dataops-configs/prometheus.yaml /opt/observability/prometheus/prometheus.yaml
    gsutil cp gs://f1-dataops-configs/local-config.yaml /opt/observability/loki/local-config.yaml
    gsutil cp gs://f1-dataops-configs/docker-compose.yaml /opt/observability/docker-compose.yaml

    cd /opt/observability
    docker compose up -d

    EOF

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "allow_grafana" {
  name    = "${var.project_base_name}-allow-grafana"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  target_tags = ["grafana-server"]

  source_ranges = ["${var.public_ip}/24"]
}