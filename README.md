# Video Encoding on Google Cloud

This tutorial shows you how to build a scalable live stream video encoding workflow on [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine) (GKE). This reference architecture includes a simulated broadcast [production truck](https://en.wikipedia.org/wiki/Production_truck) to provide a [Secure Reliable Transport (SRT)](https://en.wikipedia.org/wiki/Secure_Reliable_Transport) video signal for broadcast. This can be useful for testing streaming pipelines for live broadcast events such as sports or concerts without the need for a physical production truck.

## Objectives

-  Use [Terraform](https://www.terraform.io/downloads.html) to deploy and manage a GKE Autopilot cluster, Cloud Workflows, and other supporting infrastructure. This infrastructure will transcode the live stream video and write to a Cloud Storage Bucket via Cloud Storage FUSE.
-  Use Cloud Build to build the container image to perform the `ffmpeg` encoding.
-  Create a [Haivision SRT Gateway](https://console.cloud.google.com/marketplace/vm/config/haivision-public/haivision-srt-gateway-payg) instance from [Google Cloud Marketplace](https://console.cloud.google.com/marketplace) to prepare an SRT stream for redistribution (the "Gateway" instance).
-  Create a Compute Engine instance to generate an SRT video stream (the "Camera" instance).
-  Deploy [Media CDN](https://cloud.google.com/media-cdn/docs/overview) to distribute the live stream event to end users.

## Technology used

-  [Artifact Registry](https://cloud.google.com/artifact-registry)
-  [Cloud Storage FUSE](https://cloud.google.com/storage/docs/cloud-storage-fuse/overview)
-  [Eventarc](https://cloud.google.com/eventarc/docs/overview)
-  [Google Cloud Command Line Interface (gcloud CLI)](https://cloud.google.com/cli)
-  [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
-  [Google Workflows](https://cloud.google.com/workflows/docs/overview)
-  [Pub/Sub](https://cloud.google.com/pubsub/docs/overview)
-  [Terraform](https://www.terraform.io/downloads.html)

## Before you begin

This tutorial uses the Google Cloud CLI, which you can run from a [Cloud Shell](https://cloud.google.com/shell/docs/starting-cloud-shell) instance launched from the [Google Cloud console](https://console.cloud.google.com/). If you want to use gcloud CLI on your local workstation, install the [Google Cloud CLI](https://cloud.google.com/sdk/docs), but note that Cloud Shell has the tools used in this tutorial already installed and updated, such as `terraform` and `kubectl`.
The tutorial shows you how to run commands in Cloud Shell; if you use the gcloud CLI on your workstation, adjust the instructions accordingly.

1. In the Google Cloud console, on the [project selector page](https://console.cloud.google.com/projectselector2/home/dashboard), select or create a Google Cloud project.
1. [Make sure that billing is enabled for your Google Cloud project](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#confirm_billing_is_enabled_on_a_project).
1. [Enable the Compute Engine API](https://console.cloud.google.com/flows/enableapi?apiid=compute.googleapis.com).
1. If your project does not yet contain a default Virtual Private Cloud (VPC) network, [create one](https://cloud.google.com/vpc/docs/create-modify-vpc-networks#create-auto-network).

> [!NOTE]
> If you choose to use the gcloud CLI, make sure to update to the latest versions of the command line tools:
>
> ```
> gcloud components update
> gcloud components install kubectl
> gcloud components install gke-gcloud-auth-plugin
> ```

> [!TIP]
> If your Google Cloud Organization has enforced security best practices, you may need to modify the following [Organization Policies](https://console.cloud.google.com/iam-admin/orgpolicies/) in your project to permit this tutorial to deploy correctly:
>
> -  **compute.vmExternalIpAccess:** allow
> -  **compute.trustedImageProjects:** add project `projects/mpi-haivision-public`
> -  **compute.requireShieldedVm:** not enforced

In addition, make sure you have the following:

-  [Access to Media CDN](https://cloud.google.com/media-cdn/docs/overview#request-access) for this project.
-  Access to a new or existing domain. In a subsequent step you will add a DNS record so you can connect to your live streaming video over the internet.
-  The [Identity and Access Management (IAM) permissions](https://cloud.google.com/media-cdn/docs/configuration#permissions) required to create Media CDN resources. If you are deploying as Project Owner, you won't need additional permissions.

## Architecture

<img src="/docs/images/architecture.png" width="1000">

### Architecture notes

1. User triggers Pub/Sub topic from Cloud Shell.
1. Cloud Workflows creates a destination bucket for the encoded video and runs primary and secondary encoder workflows on GKE.
1. Camera VM generates an SRT stream and sends it to the Haivision SRT Gateway.
1. Encoder GKE pods read the stream from the Gateway over ports 5001 (primary) and 5002 (backup).
1. Encoded chunks are written to a Cloud Storage bucket via GCSFuse.
1. Edge caches, managed by Media CDN and positioned as close as possible to the request, serve the encoded video to one or more viewers.

---
| Next: [Set up your environment](docs/01_set_up_your_environment.md) |
|---:|