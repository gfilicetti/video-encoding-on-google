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

###############################
##### 1) SERVICE ACCOUNTS #####
###############################

# Create a service account for GKE cluster
resource "google_service_account" "sa_gke_cluster" {
  account_id   = "sa-${var.customer_id}-gke-cluster"
  display_name = "TF - GKE cluster SA"
  project      = local.project.id
}

###############################
###### 2) MEMBER BINDINGS #####
###############################

# GKE Workload Identity
# resource "google_service_account_iam_binding" "sa_gke_cluster_wi_binding" {
#   service_account_id = google_service_account.sa_gke_cluster.name
#   role               = "roles/iam.workloadIdentityUser"
#   members = [
#     "serviceAccount:${local.project.id}.svc.id.goog[${var.job_namespace}/k8s-sa-cluster]",
#   ]
#   depends_on = [
#     module.gke
#   ]
# }

##########################################################
###### 3.a) MEMBER ROLES - Created Service Accounts ######
##########################################################

# Add roles to the created GKE cluster service account
module "member_roles_gke_cluster" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = google_service_account.sa_gke_cluster.email
  prefix                  = "serviceAccount"
  project_id              = local.project.id
  project_roles = [
    "roles/artifactregistry.reader",
    "roles/cloudtrace.agent",
    "roles/container.admin",
    "roles/container.clusterAdmin",
    "roles/container.developer",
    "roles/container.nodeServiceAgent",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.admin",
    "roles/storage.objectUser",
  ]
}

##########################################################
###### 3.b) MEMBER ROLES - Default Service Accounts ######
##########################################################

# Add roles to the default Cloud Build service account
module "member_roles_cloudbuild" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = local.service_accounts_default.cloudbuild
  prefix                  = "serviceAccount"
  project_id              = local.project.id
  project_roles = [
    "roles/artifactregistry.reader",
    "roles/artifactregistry.repoAdmin",
    "roles/artifactregistry.serviceAgent",
    "roles/cloudbuild.builds.editor",
    "roles/cloudbuild.connectionAdmin",
    "roles/container.developer",
    "roles/iam.serviceAccountUser",
    "roles/logging.logWriter",
    "roles/storage.objectAdmin",
    "roles/storage.objectUser",
    "roles/storage.objectViewer",
  ]

  depends_on = [google_project_service_identity.service_identity]
}

# Add roles to the default Compute service account
module "member_roles_default_compute" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = local.service_accounts_default.compute
  prefix                  = "serviceAccount"
  project_id              = local.project.id
  project_roles = [
    "roles/iam.serviceAccountUser",
    # Artifact Registry
    "roles/artifactregistry.writer",
    "roles/artifactregistry.serviceAgent",
    "roles/artifactregistry.reader",
    # GKE
    "roles/container.developer",
    # Storage
    "roles/storage.admin",
    "roles/storage.objectUser",
  ]

  depends_on = [google_project_service_identity.service_identity]
}
