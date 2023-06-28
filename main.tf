module "byobcdn" {
  bucket = "byobcdn.wowless.dev"
  source = "./byobcdn"
}

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

data "google_iam_policy" "storage-backend" {}

resource "google_storage_bucket_iam_policy" "backend" {
  bucket      = google_storage_bucket.backend.name
  policy_data = data.google_iam_policy.storage-backend.policy_data
}

resource "google_storage_bucket" "backend" {
  name                        = "wowless.dev"
  location                    = "US"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

data "google_iam_policy" "storage-frontend" {
  binding {
    role    = "roles/storage.objectViewer"
    members = ["allUsers"]
  }
}

resource "google_storage_bucket_iam_policy" "frontend" {
  bucket      = google_storage_bucket.www.name
  policy_data = data.google_iam_policy.storage-frontend.policy_data
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

resource "google_compute_managed_ssl_certificate" "tactless" {
  name = "tactless"
  managed {
    domains = ["tactless.dev"]
  }
}

resource "google_compute_region_network_endpoint_group" "tactless" {
  name                  = "tactless"
  region                = "us-central1"
  network_endpoint_type = "SERVERLESS"
  cloud_function {
    function = "byobcdn-www"
  }
}

resource "google_compute_backend_service" "tactless" {
  name = "tactless"
  backend {
    group = google_compute_region_network_endpoint_group.tactless.id
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
    hosts        = ["tactless.dev"]
    path_matcher = "tactless"
  }
  path_matcher {
    default_service = google_compute_backend_service.tactless.id
    name            = "tactless"
  }
}

resource "google_compute_target_https_proxy" "frontend" {
  name = "frontend-target-proxy"
  ssl_certificates = [
    google_compute_managed_ssl_certificate.certificate.id,
    google_compute_managed_ssl_certificate.tactless.id,
  ]
  url_map = google_compute_url_map.frontend.id
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

resource "google_logging_project_bucket_config" "default" {
  project        = "projects/www-wowless-dev"
  location       = "global"
  retention_days = 30
  bucket_id      = "_Default"
  description    = "Default bucket"
}

resource "google_logging_project_sink" "default" {
  name                   = "_Default"
  destination            = "logging.googleapis.com/${google_logging_project_bucket_config.default.id}"
  unique_writer_identity = true
  filter = join(" AND ", [
    "NOT LOG_ID(\"cloudaudit.googleapis.com/activity\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/activity\")",
    "NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/system_event\")",
    "NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")",
  ])
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
      "serviceAccount:service-408547218812@gcp-sa-cloudtasks.iam.gserviceaccount.com",
    ]
    role = "roles/cloudtasks.serviceAgent"
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
      "serviceAccount:byobcdn-process-runner@www-wowless-dev.iam.gserviceaccount.com",
      "serviceAccount:byobcdn-tact-runner@www-wowless-dev.iam.gserviceaccount.com",
    ]
    role = "roles/datastore.user"
  }
  binding {
    members = [
      "serviceAccount:byobcdn-www-runner@www-wowless-dev.iam.gserviceaccount.com",
    ]
    role = "roles/datastore.viewer"
  }
  binding {
    members = [
      "serviceAccount:408547218812@cloudservices.gserviceaccount.com",
      google_service_account.github.member,
      google_service_account.terraform.member,
    ]
    role = "roles/editor"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@firebase-rules.iam.gserviceaccount.com",
    ]
    role = "roles/firebaserules.system"
  }
  binding {
    members = [
      "serviceAccount:service-408547218812@gcp-sa-firestore.iam.gserviceaccount.com",
    ]
    role = "roles/firestore.serviceAgent"
  }
  binding {
    members = [
      google_service_account.terraform.member,
    ]
    role = "roles/iam.securityAdmin"
  }
  binding {
    members = [
      "serviceAccount:408547218812@cloudbuild.gserviceaccount.com",
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
      google_service_account.terraform.member,
    ]
    role = "roles/storage.admin"
  }
}

resource "google_project_iam_policy" "project" {
  project     = "www-wowless-dev"
  policy_data = data.google_iam_policy.project.policy_data
}
