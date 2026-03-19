# --- Spot VM for Heavy Jobs (OpenSCAD, Webots, Blender) ---

# Instance template (preemptible/spot)
resource "google_compute_instance_template" "heavy_worker" {
  name_prefix  = "heavy-worker-"
  machine_type = "e2-standard-2" # 2 vCPU, 8 GB RAM — ~$0.007/hr spot
  project      = google_project.nl2bot.project_id
  region       = local.region

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    provisioning_model          = "SPOT"
    instance_termination_action = "STOP"
  }

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
    auto_delete  = true
    boot         = true
    disk_size_gb = 30
    disk_type    = "pd-standard" # cheapest
  }

  network_interface {
    network = "default"
    access_config {} # Ephemeral public IP for pulling packages
  }

  service_account {
    email  = google_service_account.spot_vm.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    gcp-project      = local.project_id
    artifacts-bucket  = google_storage_bucket.artifacts.name
    heavy-jobs-sub    = google_pubsub_subscription.heavy_jobs_pull.id
    job-results-topic = google_pubsub_topic.job_results.id
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -e
    exec > /var/log/startup.log 2>&1

    echo "=== Heavy Worker Starting ==="

    # Install deps (first boot only — cache in image for speed)
    if [ ! -f /opt/.deps_installed ]; then
      apt-get update -qq
      apt-get install -y -qq openscad xvfb python3-pip python3-venv git

      python3 -m venv /opt/worker-venv
      /opt/worker-venv/bin/pip install -q google-cloud-pubsub google-cloud-storage pyyaml trimesh numpy

      touch /opt/.deps_installed
    fi

    # Pull and run jobs
    /opt/worker-venv/bin/python3 /opt/job_runner.py &

    # Watchdog: self-terminate after 30 min or 5 min idle
    INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
    ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')

    sleep 1800
    echo "Max lifetime reached, shutting down"
    gcloud compute instances stop "$INSTANCE_NAME" --zone="$ZONE" --quiet
  SCRIPT

  tags = ["heavy-worker"]

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.services]
}

# Firewall: allow SSH for debugging
resource "google_compute_firewall" "heavy_worker_ssh" {
  name    = "heavy-worker-ssh"
  network = "default"
  project = google_project.nl2bot.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["heavy-worker"]

  depends_on = [google_project_service.services]
}
