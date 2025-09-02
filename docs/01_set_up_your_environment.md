Previous: [Video Encoding on Google Cloud](/README.md) | Next: [Create a virtual broadcast truck](02_create_a_virtual_broadcast_truck.md)
|---|---:|

---

# Set up your environment

1. In Cloud Shell, clone the repository and `cd` into the resulting directory:

    ```
    git clone https://github.com/gfilicetti/video-encoding-on-google.git
    cd video-encoding-on-google
    ```

1. In Cloud Shell, run a script to generate a file that contains environment variables used throughout the setup process:

    ```
    . ./scripts/01-setup-env.sh
    ```

    During this step you will be prompted for inputs related to your Google Cloud project. Most inputs will provide defaults that may already be set. To use a default value, press `[ENTER]` to accept and continue.

    You will be prompted for the following information:

    -  **GCP project ID:** Defaults to your project ID.
    -  **Default value region for the deployment:** defaults to `us-central1`.
    -  **Short (3-5 char) identifier for cloud resources:** defaults to `gcp`.
    -  **Name of the Google Service Account for Workload Identity:** defaults to `gsa-wi-encoder`.
    -  **Name of the Kubernetes Service Account for Workload Identity:** defaults to `ksa-wi-encoder`.
    -  **Name of the Kubernetes Namespace for Workload Identity:** defaults to `encoder-ns`.

1. Source the resulting environment file:

    ```
    . ./.env
    ```

1. Ensure you're logged in to your environment with [Application Default Credentials](https://cloud.google.com/docs/authentication/provide-credentials-adc):

    ```
    gcloud auth application-default login
    ```

1. Enable all required Google Cloud APIs for your Google Cloud project:

    ```
    . ./scripts/02-init-api.sh
    ```

## Initialize and apply the Terraform configuration

The supplied Terraform configuration deploys a GKE Autopilot cluster to scale pods that perform the live stream encoding.

1. Create a remote state bucket in Google Cloud Storage and update `terraform.tfvars`:

    ```
    . ./scripts/03-setup-tf.sh
    ```

1. In Cloud Shell, initialize Terraform using the Cloud Storage bucket created in the previous step to maintain the deployment state:

    ```
    cd terraform
    terraform init \
        -backend-config="bucket=bkt-tfstate-${GCP_PROJECT_ID}"
    ```

1. Validate the Terraform configuration prior to deployment:

    ```
    terraform validate
    ```

1. Preview Terraform changes prior to applying them:

    ```
    terraform plan \
        -out=out.tfplan \
        -var "project_id=${GCP_PROJECT_ID}" \
        -var "customer_id=${GCP_CUSTOMER_ID}" \
        -var "region=${GCP_LOCATION}"
    ```

1. Apply the Terraform configuration:

    ```
    terraform apply "out.tfplan"
    ```

> [!NOTE]
> Cloud resource deployment can take between 5-10 minutes.

## Configure GKE Cluster with Workload Identity

[Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity) lets you use IAM policies to grant Kubernetes workloads in your GKE cluster access to specific Google Cloud APIs.

1. In Cloud Shell, change directories back to the GitHub repository:

    ```
    cd video-encoding-on-google
    ```

1. Create a Google Service Account for Workload Identity for GKE:

    ```
    gcloud iam service-accounts create $GCP_GSA_WI_ENCODER
    ```

1. Apply IAM roles to the Service Account so it can access Cloud Storage:

    ```
    gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="serviceAccount:${GCP_GSA_WI_ENCODER}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/storage.objectUser" \
        --condition=None
    ```

1. Configure `kubectl` to access the GKE cluster:

    ```
    gcloud container clusters get-credentials \
        gke-${GCP_CUSTOMER_ID}-${GCP_LOCATION} \
        --region=$GCP_LOCATION \
        --project=$GCP_PROJECT_ID
    ```

1. Bind GCP and K8s Service Account for Workload Identity for GKE:

    ```
    gcloud iam service-accounts add-iam-policy-binding \
        "${GCP_GSA_WI_ENCODER}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/iam.workloadIdentityUser" \
        --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE_ENCODER}/${K8S_KSA_WI_ENCODER}]" \
        --condition=None
    ```

1. Deploy GKE Manifests for Encoder Platform:

    ```
    kubectl apply -k ./manifests/
    ```

1. Setup Workload Identity for GKE (annotate KSA):

    ```
    kubectl annotate serviceaccount "${K8S_KSA_WI_ENCODER}" \
        -n "${K8S_NAMESPACE_ENCODER}" \
        iam.gke.io/gcp-service-account="${GCP_GSA_WI_ENCODER}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    ```

## Build the encoder container image

When deployed, each GKE encoder pod runs an `ffmpeg` command, transcodes the streaming video into chunks, and writes these chunks (along with the HLS playlist file) to a Google Cloud Storage bucket, mounted using Cloud Storage FUSE.
Add IAM roles to the default Compute Engine Service Account to run Cloud Build.

1. In Cloud Shell, get the name of the default Compute Engine Service Account:

    ```
    PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")
    ```

1. Define a variable containing the name of the Service Account:

    ```
    GCE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    ```

1. Add IAM roles to the Service Account:

    ```
    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:${GCE_SA}" \
        --role="roles/artifactregistry.writer"

    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:${GCE_SA}" \
        --role="roles/logging.logWriter"

    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:${GCE_SA}" \
        --role="roles/storage.admin"
    ```

1. Build the container image using Cloud Build:**

    ```
    cd apps/encoder
    gcloud builds submit . --region=$GCP_LOCATION
    ```

> [!NOTE]
> The build can take between 3-5 minutes.

---
Previous: [Video Encoding on Google Cloud](/README.md) | Next: [Create a virtual broadcast truck](02_create_a_virtual_broadcast_truck.md)
|---|---:|