provider "google" {
  project = "www-wowless-dev"
  region = "us-central1"
  zone = "us-central1-c"
}

resource "google_cloud_run_service" "wowcig" {
  name = "wowcig"
  location = "us-central1"
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1"
        "client.knative.dev/user-image" = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowcig"
        "run.googleapis.com/client-name" = "gcloud"
        "run.googleapis.com/client-version" = "367.0.0"
        "run.googleapis.com/execution-environment" = "gen2"
      }
      labels = {
        "commit-sha" = "cdc61105afa6908824cb09110fbd608bf87084bc"
        "gcb-build-id" = "988da489-7b92-4a3d-9784-6d156d5ae156"
        "gcb-trigger-id" = "0a38aaa3-542d-46ca-826f-3c274f4b2db0"
        "managed-by" = "gcp-cloud-build-deploy-cloud-run"
      }
      name = "wowcig-00014-zom"
    }
    spec {
      container_concurrency = 1
      service_account_name = "408547218812-compute@developer.gserviceaccount.com"
      timeout_seconds = 900
      containers {
        args = []
        command = []
        image = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowcig"
        ports {
          container_port = 8080
          name = "http1"
        }
        resources {
          limits = {
            "cpu" = "1000m"
            "memory" = "4096Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_cloud_run_service" "wowless" {
  name = "wowless"
  location = "us-central1"
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "100"
        "client.knative.dev/user-image" = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowless"
        "run.googleapis.com/client-name" = "gcloud"
        "run.googleapis.com/client-version" = "367.0.0"
        "run.googleapis.com/execution-environment" = "gen2"
      }
      labels = {
        "commit-sha" = "cdc61105afa6908824cb09110fbd608bf87084bc"
        "gcb-build-id" = "b8ba6b59-5537-41ea-9c8b-5651da4817a6"
        "gcb-trigger-id" = "3ce2e9d0-87b8-4f52-8662-33db8e57c310"
        "managed-by" = "gcp-cloud-build-deploy-cloud-run"
      }
      name = "wowless-00004-rod"
    }
    spec {
      container_concurrency = 1
      service_account_name = "408547218812-compute@developer.gserviceaccount.com"
      timeout_seconds = 300
      containers {
        args = []
        command = []
        image = "us-central1-docker.pkg.dev/www-wowless-dev/docker/wowless"
        ports {
          container_port = 8080
          name = "http1"
        }
        resources {
          limits = {
            "cpu" = "1000m"
            "memory" = "4096Mi"
          }
          requests = {}
        }
      }
    }
  }
}

resource "google_cloud_run_service" "www" {
  name = "www"
  location = "us-central1"
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "4"
        "client.knative.dev/user-image" = "us-central1-docker.pkg.dev/www-wowless-dev/docker/www"
        "run.googleapis.com/client-name" = "gcloud"
        "run.googleapis.com/client-version" = "367.0.0"
        "run.googleapis.com/execution-environment" = "gen1"
      }
      labels = {
        "commit-sha" = "cdc61105afa6908824cb09110fbd608bf87084bc"
        "gcb-build-id" = "c7543308-ef44-4311-9561-c17bceb530a5"
        "gcb-trigger-id" = "4f5f4a58-8650-47c9-ae34-8512009cef44"
        "managed-by" = "gcp-cloud-build-deploy-cloud-run"
      }
      name = "www-00012-luk"
    }
    spec {
      container_concurrency = 80
      service_account_name = "408547218812-compute@developer.gserviceaccount.com"
      timeout_seconds = 300
      containers {
        args = []
        command = []
        image = "us-central1-docker.pkg.dev/www-wowless-dev/docker/www"
        ports {
          container_port = 8080
          name = "http1"
        }
        resources {
          limits = {
            "cpu" = "1000m"
            "memory" = "512Mi"
          }
          requests = {}
        }
      }
    }
  }
}
