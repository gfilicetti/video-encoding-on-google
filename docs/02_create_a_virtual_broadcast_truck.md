Previous: [Set up your environment](01_set_up_your_environment.md) | Next: [Start the encoding workflow](03_start_the_encoding_workflow.md)
|---|---:|

---

# Create a virtual broadcast truck

This page walks you through the following procedures:

- Create a [Haivision SRT Gateway](https://console.cloud.google.com/marketplace/vm/config/haivision-public/haivision-srt-gateway-payg) instance from [Google Cloud Marketplace](https://console.cloud.google.com/marketplace) to prepare an SRT stream for redistribution to the GKE encoder pods.
- Create a VM to simulate an SRT video signal from a camera.

## Create the Haivision SRT Gateway instance

1.  In the Console, navigate to the [Haivision SRT Gateway (PAYG)](https://console.cloud.google.com/marketplace/product/haivision-public/haivision-srt-gateway-payg) page in Marketplace.
1.  Click **Get Started** and choose to agree to the Marketplace Terms and agreements.
1.  Click **Deploy** and make sure additional required APIs are enabled.
    -   For this deployment, you will need to enable the **Compute Engine API** and **Infrastructure Manager API.**
1.  On the deployment page, fill in the following fields (leave everything else at default values):
    -   **Deployment name:** A unique name for this deployment.
    -   **Service account name:** A Service Account will be created to manage the deployment and configuration of the instance.
    -   **Service account ID:** This field will auto-populate with the Service Account name, but comply with resource naming restrictions.
    -   **Zone:** The region/zone in which you want the 'truck' to reside in.
    -   **Machine type:** While you can customize the machine type, the default value of `n2d-standard-4` is sufficient for most use cases.
1.  Click **Deploy**.
1.  After a few minutes, your Gateway instance will be ready.

### Configure the Gateway instance

In a Chrome browser, log into the Gateway instance to configure the Gateway.

1.  In the [Console](https://console.cloud.google.com/compute/instances), select the Haivision Gateway VM to view the instance details.
    -   Note the VM's external IP address and Instance Id (a numeric string of 20 characters).
1.  In a browser, navigate to the Gateway's external IP address.
    -   You may have to choose **Continue to site **>** Advanced **>** Proceed to [IP_ADDRESS] (unsafe)**, as the VM uses a self-signed certificate.
1.  At the prompt, the default username is `haiadmin`, and the password is the VM's Instance Id.
    -   Once logged in, you see the Administrator dashboard:

        <img src="/docs/images/01-gateway.png" width="600">

4.  Click **ADD ROUTE**, and configure the new route with the following:
    -   Give the **Route** and **Source** a unique name.
    -   **Protocol:** TS Over SRT.
    -   **Type:** Listener.
    -   **Network Interface:** Auto.
    -   **Port:** 5000
1.  Scroll down, and click **ADD DESTINATION,** and configure the following:
    -   Give the **Destination** a unique name.
    -   **Protocol:** TS Over SRT.
    -   **Type:** Listener.
    -   **Network Interface:** Auto.
    -   **Port:** 5001.
    -   Scroll down and click **SAVE.**
1.  Scroll down, and click **ADD DESTINATION,** and configure the following:
    -   Give the **Destination** a unique name.
    -   **Protocol:** TS Over SRT.
    -   **Type:** Listener.
    -   **Network Interface:** Auto.
    -   **Port:** 5002.
    -   Scroll down and click **SAVE.**
1.  Scroll down and click **CREATE.** The route and destination are created.
1.  Click the **START** icon and confirm the action. The route will initiate and the sources will show a status of CONNECTING (yellow triangle), waiting for an input stream:

    <img src="/docs/images/02-gateway.png" width="600">

## Create the Camera instance

The Camera instance will boot with a startup script that downloads example footage and streams it to the Gateway instance.

### Create a Cloud Storage bucket

The Camera instance needs to pull a script from a Cloud Storage bucket on startup. Each time the VM reboots, it will need to run this script.

1.  Open [Cloud Shell](https://console.cloud.google.com/welcome?cloudshell=true).
1.  Create a regional Google Cloud Storage bucket to contain the script for deployment:

    ```bash
    gcloud storage buckets create \
    gs://[BUCKET_NAME] \
        --location=[REGION] \
        --enable-autoclass
    ```

    Replace the following:

    -   `[BUCKET_NAME]` is a unique name for your script bucket.
    -   `[REGION]` is the region in which your Camera instance will be created.

### Add project metadata

The Camera startup script reads pre-defined variables from project metadata to know where to send the stream.

1.  In Cloud Shell, add variables to your Project Metadata:

    ```bash
    gcloud compute project-info add-metadata --metadata camera_port=[CAMERA_PORT]
    gcloud compute project-info add-metadata --metadata gateway_ip=[GATEWAY_IP_ADDRESS]
    ```

    Replace the following:

    -   `[CAMERA_PORT]` is the port where the Gateway instance receives the SRT stream, which you configured to be 5000.
    -   `[GATEWAY_IP_ADDRESS]` is the internal IP address of the Gateway instance.

1.  In Cloud Shell, from the repo directory, copy the script `start-camera.sh` to your Cloud Storage bucket:

    ```
    gcloud storage cp scripts/start-camera.sh [BUCKET_NAME]
    ```

### Create a firewall rule

The Camera instance sends an SRT stream to the Gateway over port 5000. Add a firewall rule to permit traffic over port 5000 from any VM on the VPC:

```bash
gcloud compute firewall-rules create allow-camera-srt \
    --action=ALLOW \
    --rules=udp:5000 \
    --source-ranges=10.128.0.0/9
```

### Create the instance

1.  In Cloud Shell, create the Camera instance:

    ```
    gcloud compute instances create srt-camera-vm \
        --zone=[ZONE] \
        --machine-type=e2-standard-2 \
        --maintenance-policy=MIGRATE \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --image-project=ubuntu-os-cloud \
        --image-family=ubuntu-2204-lts \
        --boot-disk-size=100 \
        --boot-disk-type=pd-balanced \
        --network=default \
        --metadata=startup-script-url=gs://[BUCKET_NAME]/start-camera.sh
    ```

    Replace the following:

    -   `[ZONE]` is the same zone as the Gateway instance.
    -   `[BUCKET_NAME]` is the name of your script bucket created earlier.

1.  In the Gateway UI, click the **Statistics** icon under **Actions**. Once the Camera instance boots and the startup script runs, you should see a connection over port 5000 streaming data to the Gateway. 

    This is your Camera instance streaming video content to the Gateway:

    <img src="/docs/images/03-gateway.png" width="600">

---
Previous: [Set up your environment](01_set_up_your_environment.md) | Next: [Start the encoding workflow](03_start_the_encoding_workflow.md)
|---|---:|