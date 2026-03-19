terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Random suffix to ensure globally unique project ID
resource "random_id" "project_suffix" {
  byte_length = 3
}

locals {
  project_id = "nl2bot-${random_id.project_suffix.hex}"
  region     = var.region
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# --- GCP Project ---
resource "google_project" "nl2bot" {
  name            = "NL2Bot"
  project_id      = local.project_id
  billing_account = var.billing_account
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
  project = google_project.nl2bot.project_id
  service = each.value

  disable_on_destroy = false
}

# --- Service Accounts ---
resource "google_service_account" "cloud_run" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
  project      = google_project.nl2bot.project_id
  depends_on   = [google_project_service.services]
}

resource "google_service_account" "spot_vm" {
  account_id   = "spot-vm-sa"
  display_name = "Spot VM Heavy Jobs"
  project      = google_project.nl2bot.project_id
  depends_on   = [google_project_service.services]
}

# --- IAM: Cloud Run SA permissions ---
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/datastore.user",          # Firestore
    "roles/storage.objectUser",      # GCS read/write
    "roles/pubsub.publisher",        # Publish heavy jobs
    "roles/aiplatform.user",         # Vertex AI
  ])
  project = google_project.nl2bot.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# --- IAM: Spot VM SA permissions ---
resource "google_project_iam_member" "spot_vm_roles" {
  for_each = toset([
    "roles/storage.objectUser",
    "roles/pubsub.subscriber",
    "roles/pubsub.publisher",
    "roles/compute.instanceAdmin.v1", # Self-delete
    "roles/logging.logWriter",
  ])
  project = google_project.nl2bot.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.spot_vm.email}"
}

# --- GCS Buckets ---
resource "google_storage_bucket" "backup" {
  name     = "${local.project_id}-backup"
  location = var.bucket_region
  project  = google_project.nl2bot.project_id

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
  project  = google_project.nl2bot.project_id

  uniform_bucket_level_access = true
  force_destroy               = false

  depends_on = [google_project_service.services]
}

# Dashboard static site bucket (public)
resource "google_storage_bucket" "dashboard" {
  name     = "${local.project_id}-dashboard"
  location = var.bucket_region
  project  = google_project.nl2bot.project_id

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
  project   = google_project.nl2bot.project_id

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
  project       = google_project.nl2bot.project_id

  depends_on = [google_project_service.services]
}
