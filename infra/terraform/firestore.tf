# --- Firestore Database (Native mode, free tier) ---
resource "google_firestore_database" "main" {
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
  project     = google_project.nl2bot.project_id

  depends_on = [google_project_service.services]
}

# Firestore indexes for common queries
resource "google_firestore_index" "projects_by_owner" {
  project    = google_project.nl2bot.project_id
  database   = google_firestore_database.main.name
  collection = "projects"

  fields {
    field_path = "owner_id"
    order      = "ASCENDING"
  }
  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "jobs_by_project" {
  project    = google_project.nl2bot.project_id
  database   = google_firestore_database.main.name
  collection = "simulation_jobs"

  fields {
    field_path = "project_id"
    order      = "ASCENDING"
  }
  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}
