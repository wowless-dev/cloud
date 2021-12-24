terraform {
  cloud {
    organization = "wowless-dev"
    workspaces {
      name = "cloud"
    }
  }
}

provider "google" {
  project = "www-wowless-dev"
  region  = "us-central1"
  zone    = "us-central1-c"
}

data "google_compute_default_service_account" "default" {}

resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "terraform"
}

resource "google_project_iam_member" "terraform-editor" {
  project = "www-wowless-dev"
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_artifact_registry_repository" "docker" {
  provider      = google-beta
  repository_id = "docker"
  format        = "DOCKER"
}

resource "google_cloud_run_service" "wowcig" {
  name                       = "wowcig"
  location                   = "us-central1"
  autogenerate_revision_name = true
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"         = "1"
        "client.knative.dev/user-image"            = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowcig"
        "run.googleapis.com/client-name"           = "gcloud"
        "run.googleapis.com/client-version"        = "367.0.0"
        "run.googleapis.com/execution-environment" = "gen1"
      }
    }
    spec {
      container_concurrency = 1
      service_account_name  = data.google_compute_default_service_account.default.email
      timeout_seconds       = 900
      containers {
        args    = []
        command = []
        image   = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowcig"
        ports {
          container_port = 8080
          name           = "http1"
        }
        resources {
          limits = {
            "cpu"    = "1000m"
            "memory" = "4096Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_cloud_run_service" "wowless" {
  name                       = "wowless"
  location                   = "us-central1"
  autogenerate_revision_name = true
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"         = "100"
        "client.knative.dev/user-image"            = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowless"
        "run.googleapis.com/client-name"           = "gcloud"
        "run.googleapis.com/client-version"        = "367.0.0"
        "run.googleapis.com/execution-environment" = "gen2"
      }
    }
    spec {
      container_concurrency = 1
      service_account_name  = data.google_compute_default_service_account.default.email
      timeout_seconds       = 300
      containers {
        args    = []
        command = []
        image   = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowless"
        ports {
          container_port = 8080
          name           = "http1"
        }
        resources {
          limits = {
            "cpu"    = "1000m"
            "memory" = "4096Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_cloud_run_service" "www" {
  name                       = "www"
  location                   = "us-central1"
  autogenerate_revision_name = true
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"         = "4"
        "client.knative.dev/user-image"            = "us-central1-docker.pkg.dev/www-wowless-dev/docker/www"
        "run.googleapis.com/client-name"           = "gcloud"
        "run.googleapis.com/client-version"        = "367.0.0"
        "run.googleapis.com/execution-environment" = "gen1"
      }
    }
    spec {
      container_concurrency = 80
      service_account_name  = data.google_compute_default_service_account.default.email
      timeout_seconds       = 300
      containers {
        args    = []
        command = []
        image   = "us-central1-docker.pkg.dev/www-wowless-dev/docker/www"
        ports {
          container_port = 8080
          name           = "http1"
        }
        resources {
          limits = {
            "cpu"    = "1000m"
            "memory" = "512Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_cloudfunctions_function" "genindex" {
  name                  = "genindex"
  runtime               = "python39"
  entry_point           = "genindex"
  environment_variables = {}
  labels                = {}
  timeouts {}
}

resource "google_cloud_scheduler_job" "wowcig-crons" {
  for_each = {
    wowcig-classic = {
      offset  = 2
      product = "wow_classic"
    }
    wowcig-classic-era = {
      offset  = 0
      product = "wow_classic_era"
    }
    wowcig-classic-era-ptr = {
      offset  = 1
      product = "wow_classic_era_ptr"
    }
    wowcig-classic-ptr = {
      offset  = 3
      product = "wow_classic_ptr"
    }
    wowcig-retail = {
      offset  = 5
      product = "wow"
    }
    wowcig-retail-ptr = {
      offset  = 4
      product = "wowt"
    }
  }
  name             = each.key
  schedule         = "0 ${each.value.offset}-23/6 * * *"
  time_zone        = "America/Chicago"
  attempt_deadline = "900s"
  http_target {
    http_method = "POST"
    uri         = "${google_cloud_run_service.wowcig.status[0].url}/wowcig?product=${each.value.product}&db2=all"
    oidc_token {
      audience              = "${google_cloud_run_service.wowcig.status[0].url}/wowcig?product=${each.value.product}&db2=all"
      service_account_email = data.google_compute_default_service_account.default.email
    }
  }
  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
    retry_count          = 0
  }
}
