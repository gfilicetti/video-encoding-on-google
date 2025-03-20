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

module "gke" {
  deletion_protection        = false
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version                    = "36.1.0"
  project_id                 = local.project.id
  name                       = "gke-${var.customer_id}"
  region                     = var.region
  network                    = module.vpc.network_name
  subnetwork                 = "default"
  ip_range_pods              = "us-central1-01-gke-01-pods"
  ip_range_services          = "us-central1-01-gke-01-services"
  horizontal_pod_autoscaling = true
  release_channel            = "RAPID" # RAPID was chosen for L4 support.
  service_account            = google_service_account.sa_gke_cluster.email
  depends_on = [
    google_service_account.sa_gke_cluster,
    module.vpc,
  ]
}
