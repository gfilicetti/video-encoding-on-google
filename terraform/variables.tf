variable "project_id" {
  description = "Unique project id for your Google Cloud project where resources will be created."
  type        = string
}

variable "customer_id" {
  description = "ID to be added to all resources that will be created."
  type        = string
  default     = "gcp"
}

variable "region" {
  description = "Region to be added to all resources that will be created."
  type        = string
  default     = "us-central1"
}

variable "clusters" {
  type = map(object({
    location = string
  }))
  description = "A list of GKE clusters to be created"
  default = [{
    "location" = "us-central1"
  },
  {
    "location" = "europe-west1"
  }]
}