# --- Cloud Run Services ---
# Set deploy_cloud_run=true after pushing Docker images to Artifact Registry

locals {
  docker_repo = "${local.region}-docker.pkg.dev/${local.project_id}/robot4kid"
}

# Planning Server
resource "google_cloud_run_v2_service" "planning" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = "planning-server"
  location = local.region
  project  = local.project_id

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${local.docker_repo}/planning-server:latest"

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true # CPU throttled when idle (cheaper)
      }

      # Secrets from Secret Manager
      env {
        name = "ANTHROPIC_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "anthropic-api-key"
            version = "latest"
          }
        }
      }
      env {
        name = "GEMINI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "gemini-api-key"
            version = "latest"
          }
        }
      }
      env {
        name = "JWT_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = "jwt-secret-key"
            version = "latest"
          }
        }
      }
      env {
        name = "ADMIN_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = "admin-password"
            version = "latest"
          }
        }
      }

      # Environment config
      env {
        name  = "ENVIRONMENT"
        value = "cloud"
      }
      env {
        name  = "GCP_PROJECT"
        value = local.project_id
      }
      env {
        name  = "GCS_ARTIFACTS_BUCKET"
        value = google_storage_bucket.artifacts.name
      }
      env {
        name  = "SIMULATION_SERVER_URL"
        value = "https://simulation-server-${data.google_project.current.number}.${local.region}.run.app"
      }
      env {
        name  = "HEAVY_JOBS_TOPIC"
        value = google_pubsub_topic.heavy_jobs.id
      }
      env {
        name  = "JOB_RESULTS_TOPIC"
        value = google_pubsub_topic.job_results.id
      }
      env {
        name  = "GRAND_AUDIT_PUBSUB_TOPIC"
        value = google_pubsub_topic.audit_done.id
      }
      env {
        name  = "GRAND_AUDIT_USE_BATCH"
        value = "true"
      }
      env {
        name  = "GCS_AUDIT_BUCKET"
        value = google_storage_bucket.artifacts.name
      }
    }

    # Cold start timeout
    timeout = "300s"
  }

  depends_on = [
    google_project_service.services,
    google_artifact_registry_repository.docker,
    google_secret_manager_secret.secrets,
  ]
}

# Simulation Server (light mode — no OpenSCAD, dispatches heavy to Spot VM)
resource "google_cloud_run_v2_service" "simulation" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = "simulation-server"
  location = local.region
  project  = local.project_id

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${local.docker_repo}/simulation-server:latest"

      ports {
        container_port = 8100
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "ENVIRONMENT"
        value = "cloud"
      }
      env {
        name  = "GCP_PROJECT"
        value = local.project_id
      }
      env {
        name  = "GCS_ARTIFACTS_BUCKET"
        value = google_storage_bucket.artifacts.name
      }
      env {
        name  = "HEAVY_JOBS_TOPIC"
        value = google_pubsub_topic.heavy_jobs.id
      }
      env {
        name = "SIM_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "sim-api-key"
            version = "latest"
          }
        }
      }
    }

    timeout = "300s"
  }

  depends_on = [
    google_project_service.services,
    google_artifact_registry_repository.docker,
  ]
}

# Public access — Cloudflare Access handles authentication at the edge
resource "google_cloud_run_v2_service_iam_member" "planning_public" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = google_cloud_run_v2_service.planning[0].name
  location = local.region
  project  = local.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "simulation_public" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = google_cloud_run_v2_service.simulation[0].name
  location = local.region
  project  = local.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}
