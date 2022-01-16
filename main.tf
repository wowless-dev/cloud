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

resource "google_project_service" "servicemanagement" {
  service = "servicemanagement.googleapis.com"
}

resource "google_service_account" "github" {
  account_id   = "github"
  display_name = "github"
}

resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "terraform"
}

resource "google_artifact_registry_repository" "docker" {
  provider      = google-beta
  repository_id = "docker"
  format        = "DOCKER"
}

resource "google_storage_bucket" "backend" {
  name                        = "wowless.dev"
  location                    = "US"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "www" {
  name                        = "www.wowless.dev"
  location                    = "US"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.txt"
  }
}

resource "google_compute_managed_ssl_certificate" "certificate" {
  name = "certificate"
  managed {
    domains = ["wowless.dev"]
  }
}

resource "google_compute_region_network_endpoint_group" "api" {
  name                  = "api"
  region                = "us-central1"
  network_endpoint_type = "SERVERLESS"
  cloud_function {
    function = google_cloudfunctions_function.api.name
  }
}

resource "google_compute_backend_service" "api" {
  name = "api"
  backend {
    group = google_compute_region_network_endpoint_group.api.id
  }
}

resource "google_compute_backend_bucket" "www" {
  name        = "www"
  bucket_name = google_storage_bucket.www.name
}

resource "google_compute_url_map" "frontend" {
  name            = "frontend"
  default_service = google_compute_backend_bucket.www.id
  host_rule {
    hosts        = ["wowless.dev"]
    path_matcher = "path-matcher-1"
  }
  path_matcher {
    default_service = google_compute_backend_bucket.www.id
    name            = "path-matcher-1"
    path_rule {
      paths   = ["/api/v1/run"]
      service = google_compute_backend_service.api.id
    }
  }
}

resource "google_compute_target_https_proxy" "frontend" {
  name             = "frontend-target-proxy"
  ssl_certificates = [google_compute_managed_ssl_certificate.certificate.id]
  url_map          = google_compute_url_map.frontend.id
}

resource "google_compute_global_address" "frontend" {
  name = "frontend"
}

resource "google_compute_global_forwarding_rule" "frontend" {
  name       = "frontend"
  labels     = {}
  target     = google_compute_target_https_proxy.frontend.id
  ip_address = google_compute_global_address.frontend.id
  port_range = "443"
}

resource "google_compute_url_map" "frontend-redirect" {
  name        = "frontend-redirect"
  description = "Automatically generated HTTP to HTTPS redirect for the frontend forwarding rule"
  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    https_redirect         = true
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "frontend-redirect" {
  name    = "frontend-target-proxy"
  url_map = google_compute_url_map.frontend-redirect.id
}

resource "google_compute_global_forwarding_rule" "frontend-redirect" {
  name       = "frontend-forwarding-rule"
  labels     = {}
  target     = google_compute_target_http_proxy.frontend-redirect.id
  ip_address = google_compute_global_address.frontend.id
  port_range = "80"
}

resource "google_service_account" "wowcig-runner" {
  account_id   = "wowcig-runner"
  display_name = "wowcig-runner"
}

data "google_iam_policy" "wowcig" {
  binding {
    members = [
      "serviceAccount:${google_service_account.wowcig-invoker.email}",
    ]
    role = "roles/run.invoker"
  }
}

resource "google_cloud_run_service_iam_policy" "wowcig" {
  service     = google_cloud_run_service.wowcig.name
  policy_data = data.google_iam_policy.wowcig.policy_data
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
        "run.googleapis.com/execution-environment" = "gen1"
      }
    }
    spec {
      container_concurrency = 1
      service_account_name  = google_service_account.wowcig-runner.email
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

resource "google_service_account" "wowless-runner" {
  account_id   = "wowless-runner"
  display_name = "wowless-runner"
}

data "google_iam_policy" "wowless" {
  binding {
    members = [
      "serviceAccount:${google_service_account.wowless-invoker.email}",
    ]
    role = "roles/run.invoker"
  }
}

resource "google_cloud_run_service_iam_policy" "wowless" {
  service     = google_cloud_run_service.wowless.name
  policy_data = data.google_iam_policy.wowless.policy_data
}

resource "google_cloud_run_service" "wowless" {
  name                       = "wowless"
  location                   = "us-central1"
  autogenerate_revision_name = true
  metadata {
    annotations = {
      "autoscaling.knative.dev/maxScale"         = "1000"
      "client.knative.dev/user-image"            = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowless"
      "run.googleapis.com/execution-environment" = "gen2"
      "run.googleapis.com/ingress"               = "all"
      "run.googleapis.com/launch-stage"          = "BETA"
    }
  }
  template {
    spec {
      container_concurrency = 1
      service_account_name  = google_service_account.wowless-runner.email
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
            "memory" = "2048Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_service_account" "depickle-runner" {
  account_id   = "depickle-runner"
  display_name = "depickle-runner"
}

resource "google_cloudfunctions_function" "depickle" {
  name                  = "depickle"
  runtime               = "python39"
  entry_point           = "depickle"
  environment_variables = {}
  labels                = {}
  trigger_http          = true
  service_account_email = google_service_account.depickle-runner.email
  timeouts {}
}

resource "google_service_account" "genindex-runner" {
  account_id   = "genindex-runner"
  display_name = "genindex-runner"
}

resource "google_cloudfunctions_function" "genindex" {
  name                  = "genindex"
  runtime               = "python39"
  entry_point           = "genindex"
  environment_variables = {}
  labels                = {}
  available_memory_mb   = 256
  event_trigger {
    event_type = "google.storage.object.finalize"
    failure_policy {
      retry = "true"
    }
    resource = "projects/_/buckets/wowless.dev"
  }
  service_account_email = google_service_account.genindex-runner.email
  timeouts {}
}

resource "google_service_account" "wowcig-invoker" {
  account_id   = "wowcig-invoker"
  display_name = "wowcig-invoker"
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
      audience              = ""
      service_account_email = google_service_account.wowcig-invoker.email
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

resource "google_service_account" "wowless-invoker" {
  account_id   = "wowless-invoker"
  display_name = "wowless-invoker"
}

data "google_iam_policy" "wowless-invoker" {
  binding {
    members = [
      "serviceAccount:${google_service_account.api-runner.email}",
    ]
    role = "roles/iam.serviceAccountUser"
  }
}

resource "google_service_account_iam_policy" "wowless-invoker" {
  service_account_id = google_service_account.wowless-invoker.name
  policy_data        = data.google_iam_policy.wowless-invoker.policy_data
}

resource "google_cloud_scheduler_job" "wowless-crons" {
  for_each = {
    wowless-classic = {
      offset  = 2
      product = "wow_classic"
    }
    wowless-classic-era = {
      offset  = 0
      product = "wow_classic_era"
    }
    wowless-classic-era-ptr = {
      offset  = 1
      product = "wow_classic_era_ptr"
    }
    wowless-classic-ptr = {
      offset  = 3
      product = "wow_classic_ptr"
    }
    wowless-retail = {
      offset  = 5
      product = "wow"
    }
    wowless-retail-ptr = {
      offset  = 4
      product = "wowt"
    }
  }
  name             = each.key
  schedule         = "${each.value.offset}-59/6 * * * *"
  time_zone        = "America/Chicago"
  attempt_deadline = "50s"
  http_target {
    http_method = "POST"
    uri         = "${google_cloud_run_service.wowless.status[0].url}/wowless?product=${each.value.product}&loglevel=1"
    oidc_token {
      audience              = ""
      service_account_email = google_service_account.wowless-invoker.email
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

resource "google_cloud_tasks_queue" "addon-downloads" {
  name     = "addon-downloads"
  location = "us-central1"
  rate_limits {
    max_concurrent_dispatches = 1
    max_dispatches_per_second = 1
  }
  retry_config {
    max_attempts  = 5
    max_backoff   = "3600s"
    max_doublings = 16
    min_backoff   = "0.100s"
  }
  timeouts {}
}

resource "google_service_account" "addon-downloader-cron-runner" {
  account_id   = "addon-downloader-cron-runner"
  display_name = "addon-downloader-cron-runner"
}

resource "google_cloudfunctions_function" "addon-downloader-cron" {
  name                  = "addon-downloader-cron"
  runtime               = "python39"
  entry_point           = "publish"
  environment_variables = {}
  labels                = {}
  available_memory_mb   = 1024
  trigger_http          = true
  service_account_email = google_service_account.addon-downloader-cron-runner.email
  timeouts {}
}

resource "google_service_account" "addon-downloader-invoker" {
  account_id   = "addon-downloader-invoker"
  display_name = "addon-downloader-invoker"
}

resource "google_service_account" "addon-downloader-runner" {
  account_id   = "addon-downloader-runner"
  display_name = "addon-downloader-runner"
}

data "google_iam_policy" "addon-downloader" {
  binding {
    members = [
      "serviceAccount:${google_service_account.addon-downloader-invoker.email}",
    ]
    role = "roles/cloudfunctions.invoker"
  }
}

resource "google_cloudfunctions_function_iam_policy" "addon-downloader" {
  cloud_function = google_cloudfunctions_function.addon-downloader.name
  policy_data    = data.google_iam_policy.addon-downloader.policy_data
}

resource "google_cloudfunctions_function" "addon-downloader" {
  name                  = "addon-downloader"
  runtime               = "python39"
  entry_point           = "handler"
  environment_variables = {}
  labels                = {}
  available_memory_mb   = 1024
  trigger_http          = true
  service_account_email = google_service_account.addon-downloader-runner.email
  timeouts {}
}

resource "google_cloud_tasks_queue" "wowless" {
  name     = "wowless"
  location = "us-central1"
  rate_limits {
    max_concurrent_dispatches = 1000
    max_dispatches_per_second = 500
  }
  retry_config {
    max_attempts  = 5
    max_backoff   = "3600s"
    max_doublings = 16
    min_backoff   = "0.100s"
  }
  timeouts {}
}

resource "google_service_account" "wowless-cron-runner" {
  account_id   = "wowless-cron-runner"
  display_name = "wowless-cron-runner"
}

resource "google_service_account" "api-runner" {
  account_id   = "api-runner"
  display_name = "api-runner"
}

data "google_iam_policy" "api" {
  binding {
    role    = "roles/cloudfunctions.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloudfunctions_function_iam_policy" "api" {
  cloud_function = google_cloudfunctions_function.api.name
  policy_data    = data.google_iam_policy.api.policy_data
}

resource "google_cloudfunctions_function" "api" {
  name                  = "api"
  runtime               = "python39"
  entry_point           = "api"
  environment_variables = {}
  labels                = {}
  available_memory_mb   = 1024
  trigger_http          = true
  service_account_email = google_service_account.api-runner.email
  ingress_settings      = "ALLOW_INTERNAL_AND_GCLB"
  timeouts {}
}

data "google_iam_policy" "project" {
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-artifactregistry.iam.gserviceaccount.com",
    ]
    role = "roles/artifactregistry.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:408547218812@cloudbuild.gserviceaccount.com",
    ]
    role = "roles/cloudbuild.builds.builder"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-cloudbuild.iam.gserviceaccount.com",
    ]
    role = "roles/cloudbuild.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcf-admin-robot.iam.gserviceaccount.com",
    ]
    role = "roles/cloudfunctions.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-cloudscheduler.iam.gserviceaccount.com",
    ]
    role = "roles/cloudscheduler.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.addon-downloader-cron-runner.email}",
      "serviceAccount:${google_service_account.api-runner.email}",
      "serviceAccount:${google_service_account.wowless-cron-runner.email}",
    ]
    role = "roles/cloudtasks.enqueuer"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-cloudtasks.iam.gserviceaccount.com",
    ]
    role = "roles/cloudtasks.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.addon-downloader-cron-runner.email}",
      "serviceAccount:${google_service_account.api-runner.email}",
      "serviceAccount:${google_service_account.wowless-cron-runner.email}",
    ]
    role = "roles/cloudtasks.viewer"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@compute-system.iam.gserviceaccount.com",
    ]
    role = "roles/compute.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@container-analysis.iam.gserviceaccount.com",
    ]
    role = "roles/containeranalysis.ServiceAgent"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@containerregistry.iam.gserviceaccount.com",
    ]
    role = "roles/containerregistry.ServiceAgent"
  }
  binding {
    members = [
      "serviceAccount:408547218812@cloudservices.gserviceaccount.com",
      "serviceAccount:${google_service_account.github.email}",
      "serviceAccount:${google_service_account.terraform.email}",
    ]
    role = "roles/editor"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-firestore.iam.gserviceaccount.com",
    ]
    role = "roles/firestore.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.terraform.email}",
    ]
    role = "roles/iam.securityAdmin"
  }
  binding {
    members = [
      "serviceAccount:408547218812@cloudbuild.gserviceaccount.com",
      "serviceAccount:${google_service_account.addon-downloader-cron-runner.email}",
      "serviceAccount:${google_service_account.wowless-cron-runner.email}",
    ]
    role = "roles/iam.serviceAccountUser"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-pubsub.iam.gserviceaccount.com",
    ]
    role = "roles/pubsub.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:408547218812@cloudbuild.gserviceaccount.com",
    ]
    role = "roles/run.admin"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@serverless-robot-prod.iam.gserviceaccount.com",
    ]
    role = "roles/run.serviceAgent"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.terraform.email}",
    ]
    role = "roles/storage.admin"
  }
}

resource "google_project_iam_policy" "project" {
  project     = "www-wowless-dev"
  policy_data = data.google_iam_policy.project.policy_data
}

data "google_iam_policy" "storage-backend" {
  binding {
    members = [
      "serviceAccount:${google_service_account.addon-downloader-runner.email}",
      "serviceAccount:${google_service_account.api-runner.email}",
      "serviceAccount:${google_service_account.depickle-runner.email}",
      "serviceAccount:${google_service_account.wowcig-runner.email}",
      "serviceAccount:${google_service_account.wowless-runner.email}",
    ]
    role = "roles/storage.objectAdmin"
  }
  binding {
    members = [
      "serviceAccount:${google_service_account.addon-downloader-cron-runner.email}",
      "serviceAccount:${google_service_account.genindex-runner.email}",
      "serviceAccount:${google_service_account.wowless-cron-runner.email}",
    ]
    role = "roles/storage.objectViewer"
  }
}

resource "google_storage_bucket_iam_policy" "backend" {
  bucket      = google_storage_bucket.backend.name
  policy_data = data.google_iam_policy.storage-backend.policy_data
}

data "google_iam_policy" "storage-frontend" {
  binding {
    members = [
      "serviceAccount:${google_service_account.genindex-runner.email}",
    ]
    role = "roles/storage.objectAdmin"
  }
  binding {
    role    = "roles/storage.objectViewer"
    members = ["allUsers"]
  }
}

resource "google_storage_bucket_iam_policy" "frontend" {
  bucket      = google_storage_bucket.www.name
  policy_data = data.google_iam_policy.storage-frontend.policy_data
}
