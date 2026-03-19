output "project_id" {
  description = "GCP project ID"
  value       = local.project_id
}

output "project_number" {
  description = "GCP project number"
  value       = data.google_project.current.number
}

# --- Buckets ---
output "backup_bucket" {
  description = "GCS backup bucket"
  value       = google_storage_bucket.backup.name
}

output "artifacts_bucket" {
  description = "GCS artifacts bucket (projects, jobs, renders)"
  value       = google_storage_bucket.artifacts.name
}

output "dashboard_bucket" {
  description = "GCS dashboard static site bucket"
  value       = google_storage_bucket.dashboard.name
}

output "dashboard_url" {
  description = "Dashboard static site URL"
  value       = "https://storage.googleapis.com/${google_storage_bucket.dashboard.name}/index.html"
}

# --- Cloud Run ---
output "planning_server_url" {
  description = "Planning Server Cloud Run URL"
  value       = var.deploy_cloud_run ? google_cloud_run_v2_service.planning[0].uri : "(not deployed yet)"
}

output "simulation_server_url" {
  description = "Simulation Server Cloud Run URL"
  value       = var.deploy_cloud_run ? google_cloud_run_v2_service.simulation[0].uri : "(not deployed yet)"
}

# --- Docker ---
output "docker_repo" {
  description = "Artifact Registry Docker repo"
  value       = "${local.region}-docker.pkg.dev/${local.project_id}/robot4kid"
}

# --- Pub/Sub ---
output "heavy_jobs_topic" {
  value = google_pubsub_topic.heavy_jobs.id
}

output "job_results_topic" {
  value = google_pubsub_topic.job_results.id
}

output "audit_done_topic" {
  value = google_pubsub_topic.audit_done.id
}

# --- Service Accounts ---
output "cloud_run_sa" {
  value = google_service_account.cloud_run.email
}
