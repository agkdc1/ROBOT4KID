variable "billing_account" {
  description = "GCP billing account ID"
  type        = string
  default     = "01379E-748455-3FDDAA"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "bucket_region" {
  description = "GCS bucket region (us-west1 for free tier)"
  type        = string
  default     = "us-west1"
}
