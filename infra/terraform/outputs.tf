output "project_id" {
  description = "GCP project ID"
  value       = google_project.nl2bot.project_id
}

output "backup_bucket" {
  description = "GCS backup bucket name"
  value       = google_storage_bucket.backup.name
}

output "secret_anthropic" {
  description = "Secret Manager ID for Anthropic API key"
  value       = google_secret_manager_secret.anthropic_key.secret_id
}

output "secret_gemini" {
  description = "Secret Manager ID for Gemini API key"
  value       = google_secret_manager_secret.gemini_key.secret_id
}

output "secret_jwt" {
  description = "Secret Manager ID for JWT secret"
  value       = google_secret_manager_secret.jwt_secret.secret_id
}
