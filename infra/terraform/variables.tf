variable "billing_account" {
  description = "GCP billing account ID"
  type        = string
  default     = "01379E-748455-3FDDAA"
}

variable "region" {
  description = "GCP region for Cloud Run / Firestore"
  type        = string
  default     = "us-west1"
}

variable "bucket_region" {
  description = "GCS bucket region (us-west1 for free tier)"
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
  description = "Admin email for Cloud Run invoker"
  type        = string
  default     = "ahnchoonghyun@gmail.com"
}
