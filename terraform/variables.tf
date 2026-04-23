variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "public_ip" {
  description = "Public IP of my local machine"
  type        = string
  sensitive   = true
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