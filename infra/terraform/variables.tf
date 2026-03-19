variable "project_id" {
  description = "GCP project ID (must already exist with billing enabled)"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run / Firestore"
  type        = string
  default     = "us-west1"
}

variable "bucket_region" {
  description = "GCS bucket region (US for multi-region free tier)"
  type        = string
  default     = "US"
}

variable "domain" {
  description = "Primary domain (set via tfvars, never committed)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "admin_email" {
  description = "Admin email for notifications"
  type        = string
  default     = ""
}

variable "deploy_cloud_run" {
  description = "Set to true after Docker images are pushed to Artifact Registry"
  type        = bool
  default     = false
}
