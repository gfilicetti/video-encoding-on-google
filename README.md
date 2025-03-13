# Video Encoding on Google Cloud

This is an example architecture to build out and benchmark a simple live stream
video encoding on Google Cloud's GKE.

<!-- Create table of contents that link to below sections in markdown -->
- [Architecture](#architecture)
- [Technology Used](#technology-used)
- [Initializing Your Project](#initializing-your-project)
- [Setting up GitHub Actions](#setting-up-github-actions)
- [Provisioning Infrastructure (encoder)](#provisioning-infrastructure-encoder)
- [Creating the "truck"](#creating-the-truck)
  - [Truck infrascture on Google Cloud](#truck-infrascture-on-google-cloud)
- [Kickoff encoding workflow](#kickoff-encoding-workflow)
- Misc
  - [GitHub Actions](./docs/githubactions.md)
  - [Terraform Details](./docs/terraform/README.md)

## Architecture
![High level architecture](docs/images/arch.png "High level architecture")

## Technology Used
**Code management (GitHub)**
- [GitHub Actions](https://docs.github.com/en/actions)
- [GitHub CLI](https://github.com/cli/cli#installation)

**Google Cloud**
- [Artifact Registry](https://cloud.google.com/artifact-registry/docs)
- [Cloud Storage Fuse](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver)
- [Eventarc](https://cloud.google.com/eventarc/docs/overview)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Google Workflows](https://cloud.google.com/workflows/docs/overview)
- [Pub/Sub](https://cloud.google.com/pubsub/docs/overview)

**Infrastructure as Code**
- [Terraform](https://www.terraform.io/downloads.html)

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
  . ./scripts/01-setup-env.sh
  ```
  During this step you will be prompted for a couple inputs relative to your unique project. Most
  inputs will contain defaults that might already be set, in which case go ahead and press [ENTER]
  to accept and continue.

    a. The GitHub username/organization. This is the value used above when you cloned your fork.
    b. The name of the GitHub repository, by default this is set to `gke-github-deployment`.
    c. Your unique Google Cloud project ID.
    d. Defaut region location for Google Cloud setup.
    e. A short (3-5 char) identifier for your cloud resources (e.g. gcp).

6. Enable all the needed Google Cloud APIs by running this script:

  ```bash
  . ./scripts/02-enable-api.sh
  ```

7. Setup GitHub Actions. This includes setting up workload identity pools and
Google Cloud service accounts with correct permissions to deploy infrastructure.
More details on GitHub Actions can be found [here](./docs/githubactions.md)

  ```bash
  . ./scripts/03-setup-github-actions.sh

  . ./scripts/04-setup-iam.sh
  ```

8. Initial setup to for Terraform. Create Terraform `vars` and remote state state bucket in GCS.

  ```bash
  . ./scripts/05-setup-terraform.sh
  ```

## Running GitHub Actions

This repository makes heavy use of GitHub Actions. Instructions for setting up and using GitHub Actions can be [found here](./github-actions/README.md).

There are 3 major workflows as part of the deployment process that are automated and can be ran manually, or setup with a trigger. The workflows are as follows:

1. [Applying](./.github/workflows/terrafrom-apply.yaml) and [destroying](./github/workflows/terrafrom-destroy.yaml)Terraform infrastructure
2. Building the [FFMPEG](./.github/workflows/continuous-delivery-encoder.yaml) application to run on GKE.
3. [Applying](./.github/workflows/kubectl-apply.yaml) kubernetes based platform configurations to GKE.

## Creating the "truck"

In order to create a stream we will need to simulate an on-site event, further
refered to as a truck. If you alread have a simulation in place, you may kickoff
the encoder setup by sending the following message to Pub/Sub

```bash
gcloud pubsub topics publish encoder-topic \
  --message='{"truckOriginIp": "0.0.0.0", "eventId": "sportsball-2025-03-14-v1", "region": :"us-central1"}'
```

### Truck infrascture on Google Cloud

In order to simulate a truck on Google Cloud, you can run through the following
setup that stands up a Google Compute Engine instance and listens for the
encoder to stream to.

Create and event and specify its location.

```bash
export EVENT="sportsball1234"
export TRUCK_LOCATION="us-central1"
export PROJECT_ID=$(gcloud config get-value project)
```

If you do not have a default VPC, go ahead an create one
```bash
gcloud compute networks create default \
    --subnet-mode=auto \
    --bgp-routing-mode=global
```

Reserve and static IP Adress to use for out "event"

```bash
gcloud compute addresses create ${EVENT}-ip --region=${TRUCK_LOCATION}
```

Declare some environment variables to use in the creation of our instance.

```bash
export TRUCK_IP=`gcloud compute addresses list --filter=name=${EVENT}-ip --format='value(address)'`
export TRUCK_PRIMARY="${TRUCK_IP}:5000"
export TRUCK_BACKUP="${TRUCK_IP}:5001"

export TIMESTAMP=`date +%Y%M%dt%H%M`
```

Upload truck starter script to GCS to be used on GCE creation.

```bash
gcloud storage buckets create gs://bkt-${PROJECT_ID}-truck-startup --location=${TRUCK_LOCATION}
gsutil cp ./scripts/truck-startup.sh gs://bkt-${PROJECT_ID}-truck-startup
```

```bash
gcloud compute instances create srt-stream-sender-${EVENT}-$TIMESTAMP \
  --zone=${TRUCK_LOCATION}-c \
  --machine-type=n2d-highmem-4 \
  --maintenance-policy=MIGRATE \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=srt-truck \
  --image-project=ubuntu-os-cloud \
  --image-family=ubuntu-2204-lts \
  --boot-disk-size=100 \
  --boot-disk-type=pd-balanced \
  --network=default \
  --shielded-secure-boot \
  --address=${TRUCK_IP} \
  --instance-termination-action=DELETE \
  --max-run-duration=16m \
  --metadata-from-file=startup-script=./scripts/truck-startup.sh
  # --metadata=startup=gs://bkt-${PROJECT_ID}-truck-startup/truck-startup.sh
```

### Kickoff encoding workflow

As an example we will use Pub/Sub to kickoff our encoder workloads (primary and backup) to start a
live encoding from the "truck".

Pub/Sub schema will need the `truckOriginIp`, a unique `event` identifier, and the `region` for the location
of the event to sync the encoder as close as possible to the truck.

```bash
gcloud pubsub topics publish encoder-topic \
  --message="{\"truckOriginIp\": \"${TRUCK_IP}\", \"eventId\": \"${EVENT}\", \"region\": \"${TRUCK_LOCATION}\"}"
```


```bash
status="none"
while [ "${status}" != "stopping" ]; do
  statusnew="`gcloud compute instances list --filter=srt-stream-sender-${EVENT} |grep STATUS|awk '{print $2}'`"
  if [ "${statusnew}" == "RUNNING" ]; then
     prim_files=`gcloud storage ls gs://${GCS_OUT_NAME}/ffmpeg-${EVENT}* |wc -l`
     sec_files=`gcloud storage ls gs://${GCS_OUTBKP_NAME}/ffmpeg-${EVENT}* |wc -l`
     status="running"
     echo "Status is running"
     echo
     date
     echo
     echo -e "Files generated \nPrimary Bucket = $prim_files \nBackup Bucket = $sec_files\n"
     sleep 5
     kubectl -n ffmpeg get pods -l app=ffmpeg-${EVENT};echo; kubectl -n ffmpeg top pods -l app=ffmpeg-${EVENT}; echo; gcloud compute instances list --filter=srt-stream-sender-${EVENT}; echo; kubectl -n ffmpeg logs -l app=ffmpeg-${EVENT} --tail=1
     sleep 5
  fi
  if [ "${status}" = "running" ]; then
     if [ "${statusnew}" == "STOPPING" ]||[ "${statusnew}" == "" ]; then
        status="stopping"
        echo "VM stopping"
        gcloud compute instances list --filter=srt-stream-sender-${EVENT}
     fi
  fi
done
```
