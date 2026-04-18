variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "project_base_name" {
  description = "Base name for resources"
  type        = string
  default     = "f1-pipeline"
}

variable "extractor_image_tag" {
  description = "The Docker image tag to deploy for the Cloud Run Job"
  type        = string
}