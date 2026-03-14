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
  region = local.region
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
  ])
  project = google_project.nl2bot.project_id
  service = each.value

  disable_on_destroy = false
}

# --- GCS Bucket for Backups ---
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

# --- Secret Manager: Anthropic API Key ---
resource "google_secret_manager_secret" "anthropic_key" {
  secret_id = "anthropic-api-key"
  project   = google_project.nl2bot.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}

# --- Secret Manager: Gemini API Key ---
resource "google_secret_manager_secret" "gemini_key" {
  secret_id = "gemini-api-key"
  project   = google_project.nl2bot.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}

# --- Secret Manager: JWT Secret ---
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret-key"
  project   = google_project.nl2bot.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}
