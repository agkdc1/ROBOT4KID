# --- Cloud Run Job for heavy tasks (OpenSCAD, Blender) ---
# Replaces Spot VM — simpler ops, same cost

resource "google_cloud_run_v2_job" "heavy_worker" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = "heavy-worker"
  location = local.region
  project  = local.project_id

  template {
    task_count = 1

    template {
      service_account = google_service_account.cloud_run.email
      timeout         = "600s"
      max_retries     = 1

      containers {
        image = "${local.docker_repo}/heavy-worker:latest"

        resources {
          limits = {
            cpu    = "4"
            memory = "16Gi"
          }
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
          name  = "HEAVY_JOBS_SUB"
          value = google_pubsub_subscription.heavy_jobs_pull.id
        }
        env {
          name  = "JOB_RESULTS_TOPIC"
          value = google_pubsub_topic.job_results.id
        }
      }
    }
  }

  depends_on = [
    google_project_service.services,
    google_artifact_registry_repository.docker,
  ]
}
