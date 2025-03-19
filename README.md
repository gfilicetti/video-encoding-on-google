# Video Encoding on Google Cloud

This is an example architecture to build out and benchmark a simple live stream
video encoding on Google Cloud's GKE.

## Architecture
![High level architecture](docs/images/arch.png "High level architecture")

## Technology Used
- [GitHub CLI](https://github.com/cli/cli#installation)
- [Terraform](https://www.terraform.io/downloads.html)
- [Artifact Registry](https://cloud.google.com/artifact-registry/docs)
- [GitHub Actions](https://docs.github.com/en/actions)
- [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Google Workflows](https://cloud.google.com/workflows/docs/overview)
- [Eventarc](https://cloud.google.com/eventarc/docs/overview)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [gcloud](https://cloud.google.com/sdk/docs/install)

## Initializing Your Project

These instructions walk you through setting up your environment for this
project.

You will need to clone this repository to the machine you want to use to set up
your Google Cloud environment.

> **NOTE:** We recommended using Google Cloud Shell instead of your local
> laptop. Cloud Shell has all the tooling you need already pre-installed.

1. First authenticate to Google Cloud:

  ```bash
  gcloud auth application-default login
  ```

2. Create a new project (skip this if you already have a project created):

  ```bash
  gcloud projects create <your-project-id>
  ```

3. Set the new project as your context for the `gcloud` CLI:

  ```bash
  gcloud config set project <your-project-id>
  ```

4. Check if your authentication is ok and your project id is set:

  ```bash
  gcloud projects describe <your-project-id>
  ```

> __Note:__ You should see your `projectId` listed with an `ACTIVE` state.

5. Setup your unique `.env` variables to be used throughout the setup
process

  ```bash
  bash ./scripts/setup-env.sh
  ```

6. Finally, enable all the needed Google Cloud APIs by running this script:

  ```bash
  bash ./scripts/enable-api.sh
  ```

During this step you will be prompted for a couple inputs relative to your unique project. Most
inputs will contain defaults that might already be set, in which case go ahead and press [ENTER]
to accept and continue.

1. The GitHub username/organization. This is the value used above when you cloned your fork.
2. The name of the GitHub repository, by default this is set to `gke-github-deployment`.
3. Your unique Google Cloud project ID.
4. Defaut region location for Google Cloud setup.
5. A short (3-5 char) identifier for your cloud resources (e.g. gcp).

## (Optional) Setting up GitHub Actions

Instructions for setting up and using GitHub Actions can be [found here](./github-actions/README.md).

## Provisioning Infrastructure

There are 2 options for deployment:

1. Run the `terraform` CLI on the command line directly. [See instructions here.](./terraform/README.md)

2. Use a GitHub Action to run all the Terraform configuration files. [See instructions here.](./github-actions/README.md)

## Execute

```
gcloud pubsub topics publish encoder-topic \
  --message='{"camOriginIp": "0.0.0.0", "camOriginPort": "5000", "eventId": "sportsball-2025-03-14-v1", "isBackup": false}'

gcloud pubsub topics publish encoder-topic \
  --message='{"camOriginIp": "0.0.0.0", "camOriginPort": "5001", "eventId": "sportsball-2025-03-14-v1", "isBackup": true}'
```

```
gcloud compute instances create srt-stream-sender \
  --zone=us-central1-f \
  --machine-type=n2d-highmem-4 \
  --maintenance-policy=MIGRATE \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=ffmpeg-server \
  --image-project=ubuntu-os-cloud \
  --image-family=ubuntu-2204-lts \
  --boot-disk-size=100 \
  --boot-disk-type=pd-balanced \
  --network=default \
  --shielded-secure-boot \
  --address=${CAM_IP} \
  --max-run-duration=10m \
  --instance-termination-action=DELETE \
  --metadata=startup-script-uri=gs://<SOME_BUCKET_NAME>/sender-startup.sh
```
