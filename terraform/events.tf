# Create a service account for Eventarc trigger and Workflows
resource "google_service_account" "eventarc" {
  account_id   = "eventarc-workflows-sa"
  display_name = "Eventarc Workflows Service Account"
}

module "member_roles_eventarc" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = google_service_account.eventarc.email
  prefix                  = "serviceAccount"
  project_id              = local.project.id
  project_roles = [
    "roles/compute.viewer",
    "roles/iam.serviceAccountUser",
    # Grant permissions to Artifact Registry
    "roles/artifactregistry.writer",
    "roles/artifactregistry.serviceAgent",
    "roles/artifactregistry.reader",
    # Grant permission to run workloads on GKE
    "roles/container.developer",
    # Grant permission to create storage buckets
    "roles/storage.admin",
    "roles/storage.objectUser",
    # Grant permission to invoke Workflows
    "roles/workflows.invoker",
    # Grant permission to receive events
    "roles/eventarc.eventReceiver",
    # Grant permission to write logs
    "roles/logging.logWriter",
  ]
}

# Create Workflows as an event receiver
data "local_file" "encoder_schema" {
  filename = "./definitions/pubsub-schema.json"
}

# Create Pub/Sub schema for topic
resource "google_pubsub_schema" "encoder" {
  name = "encoder-schema"
  type = "AVRO"
  definition = data.local_file.encoder_schema.content
}

# Create Pub/Sub topic as an event provider
resource "google_pubsub_topic" "encoder" {
  name = "encoder-topic"
  schema_settings {
    schema = "projects/${local.project.name}/schema/encoder-schema"
    encoding = "JSON"
  }

  depends_on = [google_pubsub_schema.encoder]
}

# Create Workflows as an event receiver
data "local_file" "encoder_workflow" {
  filename = "./definitions/workflow.yaml"
}

# Create a workflow
resource "google_workflows_workflow" "encoder" {
  name            = "encoder-workflow"
  region          = var.region
  description     = "Deploy new encoder for stream"
  service_account = google_service_account.eventarc.email

  user_env_vars = {
    DOCKER_REPO_URI = "${var.region}-docker.pkg.dev/${local.project.id}/video-encoding/"
    GKE_CLUSER_NAME = module.gke.name
  }

  source_contents = data.local_file.encoder_workflow.content
}

# Defined Eventarc trigger
resource "google_eventarc_trigger" "encoder" {
  name            = "encoder-trigger"
  location        = var.region
  service_account = google_service_account.eventarc.email
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  destination {
    workflow = google_workflows_workflow.encoder.id
  }
  transport {
    pubsub {
      topic = google_pubsub_topic.encoder.id
    }
  }
}
