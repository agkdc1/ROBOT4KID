# --- Pub/Sub Topics ---

# Heavy job dispatch (Cloud Run → Spot VM)
resource "google_pubsub_topic" "heavy_jobs" {
  name    = "heavy-jobs"
  project = local.project_id

  message_retention_duration = "3600s" # 1 hour

  depends_on = [google_project_service.services]
}

# Job results (Spot VM → Cloud Run)
resource "google_pubsub_topic" "job_results" {
  name    = "job-results"
  project = local.project_id

  message_retention_duration = "3600s"

  depends_on = [google_project_service.services]
}

# Grand Audit completion notifications
resource "google_pubsub_topic" "audit_done" {
  name    = "grand-audit-done"
  project = local.project_id

  message_retention_duration = "3600s"

  depends_on = [google_project_service.services]
}

# --- Subscriptions ---

# Spot VM pulls heavy jobs
resource "google_pubsub_subscription" "heavy_jobs_pull" {
  name    = "heavy-jobs-pull"
  topic   = google_pubsub_topic.heavy_jobs.id
  project = local.project_id

  ack_deadline_seconds       = 600 # 10 min for long jobs
  message_retention_duration = "3600s"

  expiration_policy {
    ttl = "" # Never expire
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

# Planning server pulls job results
resource "google_pubsub_subscription" "job_results_pull" {
  name    = "job-results-pull"
  topic   = google_pubsub_topic.job_results.id
  project = local.project_id

  ack_deadline_seconds       = 30
  message_retention_duration = "3600s"

  expiration_policy {
    ttl = ""
  }
}

# Audit completion pull
resource "google_pubsub_subscription" "audit_done_pull" {
  name    = "grand-audit-done-pull"
  topic   = google_pubsub_topic.audit_done.id
  project = local.project_id

  ack_deadline_seconds       = 30
  message_retention_duration = "3600s"

  expiration_policy {
    ttl = ""
  }
}
