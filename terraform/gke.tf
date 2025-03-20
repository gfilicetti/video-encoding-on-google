# Copyright 2023 Google LLC All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# google_client_config and kubernetes provider must be explicitly specified like the following.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

resource "google_container_cluster" "primary" {
  deletion_protection        = false

  name                       = "gke-${var.customer_id}"
  project                    = local.project.id
  location                   = var.region
  network                    = module.vpc.network_name
  subnetwork                 = "default"

  enable_autopilot = true

  release_channel {
    channel = "RAPID"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block = "/16"
    services_ipv4_cidr_block = "/26"
  }

  node_config {
    service_account = google_service_account.sa_gke_cluster.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  depends_on = [
    google_service_account.sa_gke_cluster,
    module.vpc,
  ]
}
