terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  project_id = var.project_id
  region     = var.region
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# Look up project number from project ID
data "google_project" "current" {
  project_id = local.project_id
}

# --- Enable APIs ---
resource "google_project_service" "services" {
  for_each = toset([
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "firestore.googleapis.com",
    "pubsub.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "aiplatform.googleapis.com",
  ])
  project = local.project_id
  service = each.value

  disable_on_destroy = false
}

# --- Service Accounts ---
resource "google_service_account" "cloud_run" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
  project      = local.project_id
  depends_on   = [google_project_service.services]
}

# --- IAM: Cloud Run SA permissions (used by services + jobs) ---
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/datastore.user",          # Firestore
    "roles/storage.objectUser",      # GCS read/write
    "roles/pubsub.publisher",        # Publish job results
    "roles/pubsub.subscriber",       # Pull heavy jobs (Cloud Run Job)
    "roles/aiplatform.user",         # Vertex AI batch prediction
    "roles/run.developer",           # Execute Cloud Run Jobs
  ])
  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# --- GCS Buckets ---
resource "google_storage_bucket" "backup" {
  name     = "${local.project_id}-backup"
  location = local.region  # Same region as services (existing bucket is US-WEST1)
  project  = local.project_id

  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket" "artifacts" {
  name     = "${local.project_id}-artifacts"
  location = var.bucket_region
  project  = local.project_id

  uniform_bucket_level_access = true
  force_destroy               = false

  depends_on = [google_project_service.services]
}

# Dashboard static site bucket (public)
resource "google_storage_bucket" "dashboard" {
  name     = "${local.project_id}-dashboard"
  location = var.bucket_region
  project  = local.project_id

  uniform_bucket_level_access = true
  force_destroy               = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html" # SPA fallback
  }

  depends_on = [google_project_service.services]
}

# Public access for dashboard bucket
resource "google_storage_bucket_iam_member" "dashboard_public" {
  bucket = google_storage_bucket.dashboard.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# --- Secret Manager ---
resource "google_secret_manager_secret" "secrets" {
  for_each  = toset(["anthropic-api-key", "gemini-api-key", "jwt-secret-key", "sim-api-key", "admin-password"])
  secret_id = each.value
  project   = local.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}

# --- Artifact Registry ---
resource "google_artifact_registry_repository" "docker" {
  location      = local.region
  repository_id = "robot4kid"
  format        = "DOCKER"
  project       = local.project_id

  depends_on = [google_project_service.services]
}
