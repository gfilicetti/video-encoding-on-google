# Create a virtual broadcast truck

This tutorial shows you how to build infrastructure on Google Cloud to simulate a [Secure Reliable Transport (SRT)](https://en.wikipedia.org/wiki/Secure_Reliable_Transport) video signal from a broadcast [production truck](https://en.wikipedia.org/wiki/Production_truck). This can be useful for testing transcoding or streaming pipelines for live broadcast events such as sports or concerts without the need for a physical production truck.

## Objectives

-  Create a Compute Engine instance to generate an SRT video stream (the "Sender" instance).
-  Create a [Haivision SRT Gateway](https://console.cloud.google.com/marketplace/vm/config/haivision-public/haivision-srt-gateway-payg) instance from [Google Cloud Marketplace](https://console.cloud.google.com/marketplace) to prepare an SRT stream for redistribution to multiple destinations (the "Gateway" instance).
-  Create a Compute Engine instance to encode the SRT stream and write to disk in segments (the "Caller" instance).

## Costs

The resources and factors that affect cost in this tutorial are:

### Sender

-  2 vCPUs, 8 GB RAM [e2-standard-2 machine type](https://cloud.google.com/compute/vm-instance-pricing#tg6-t1) 
-  20 GB SSD [balanced persistent boot disk](https://cloud.google.com/compute/disks-image-pricing?e=48754805&hl=en#tg1-t0)

### Gateway

-  4 vCPUs, 16 GB RAM [n2d-standard-4 machine type](https://cloud.google.com/compute/vm-instance-pricing#tg8-t0)
-  100 GB [SSD persistent boot disk](https://cloud.google.com/compute/disks-image-pricing?e=48754805&hl=en#tg1-t0)
-  [Haivision SRT Gateway usage fee](https://console.cloud.google.com/marketplace/product/haivision-public/haivision-srt-gateway-payg)

### Caller

-  4 vCPUs, 16 GB RAM [n2d-standard-4 machine type](https://cloud.google.com/compute/vm-instance-pricing#tg8-t0)
-  200 GB [SSD persistent boot disk](https://cloud.google.com/compute/disks-image-pricing?e=48754805&hl=en#tg1-t0)

All resources are subject to [vm-to-vm network pricing](https://cloud.google.com/vpc/network-pricing?e=48754805&hl=en#tg0-t1).  

You can use the [Google Cloud Calculator](https://cloud.google.com/products/calculator?hl=en&dl=CjhDaVF4TUdNNVlURXlNQzB5TmpGaExUUTVOell0T1dJeE55MWpaR1F6TVRGaE1EaG1PVEVRQVE9PRAIGiQ1MDYzNTU5OS1GMkE0LTQ0OUUtOUM1Ri05ODFFMTI3MjgyMjI) to further understand costs.  

> [!NOTE]
> This tutorial uses third-party software from Haivision that is billable through Google Cloud Marketplace.

## Before you begin

This tutorial uses the Google Cloud CLI, which you can run from a [Cloud Shell](https://cloud.google.com/shell/docs/starting-cloud-shell) instance launched from the [Google Cloud console](https://console.cloud.google.com/). If you want to use gcloud CLI on your local workstation, install the [Google Cloud CLI](https://cloud.google.com/sdk/docs). The tutorial shows you how to run commands in Cloud Shell; if you use the gcloud CLI on your workstation, adjust the instructions accordingly.

1. In the Google Cloud console, on the [project selector page](https://console.cloud.google.com/projectselector2/home/dashboard), select or create a Google Cloud project.
1. [Make sure that billing is enabled for your Google Cloud project](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#confirm_billing_is_enabled_on_a_project).
1. [Enable the Compute Engine API](https://console.cloud.google.com/flows/enableapi?apiid=compute.googleapis.com).
1. If your project does not yet contain a default Virtual Private Cloud (VPC) network, [create one](https://cloud.google.com/vpc/docs/create-modify-vpc-networks#console).

## Architecture

The following diagram shows the components used in this tutorial to deploy a single virtual broadcast truck environment:

<img src="/docs/images/vbt-arch.png" width="600">

## Clone the repository

In Cloud Shell, clone the repository:

```
git clone https://github.com/gfilicetti/video-encoding-on-google.git
```

## Create a Cloud Storage bucket

The Sender instance needs to pull a script from a Cloud Storage bucket on startup. 

1. Open [Cloud Shell](https://console.cloud.google.com/welcome?cloudshell=true).
1. Create a regional Google Cloud Storage bucket to contain the script for deployment:

    ```
    gcloud storage buckets create \
        gs://[BUCKET_NAME] \
        --location=[REGION] \
        --enable-autoclass
    ```

    Replace the following:

    -  `[BUCKET_NAME]` is a unique name for your script bucket.
    -  `[REGION]` is the region in which your Sender instance will be created.

## Create the Haivision SRT Gateway instance

Create this instance before the others, as you will need the internal IP address for subsequent steps.

1. In the Console, navigate to the [Haivision SRT Gateway (PAYG)](https://console.cloud.google.com/marketplace/product/haivision-public/haivision-srt-gateway-payg) page in Marketplace.
1. Click **Get Started** and choose to agree to the Marketplace Terms and agreements.
1. Click **Deploy** and make sure additional required APIs are enabled.
    - For this deployment, you will need to enable the **Compute Engine API** and **Infrastructure Manager API.**
1. On the deployment page, fill in the following fields (leave everything else at default values):
    -  **Deployment name:** A unique name for this deployment.
    -  **Service account name:** A Service Account will be created to manage the deployment and configuration of the instance.
    -  **Service account ID:** This field will auto-populate with the Service Account name, but comply with resource naming restrictions.
    -  **Zone:** The region/zone in which you want the 'truck' to reside in. Should be in the same region as your storage bucket.
    -  **Machine type:** While you can customize the machine type, the default value of `n2d-standard-4` is sufficient for most use cases.
1. Click **Deploy**.
1. After a few minutes, your Gateway instance will be ready.

## Configure the Gateway instance

In a Chrome browser, log into the Gateway instance to configure the Gateway.

1. In the [Console](https://console.cloud.google.com/compute/instances), select the Haivision Gateway VM to view the instance details.
    - Note the VM's external IP address and Instance Id (a numeric string of 20 characters).
1. In a browser, navigate to the Gateway's external IP address. 
    - You may have to choose **Continue to site **>** Advanced **>** Proceed to [IP_ADDRESS] (unsafe)**, as the VM uses a self-signed certificate.
1. At the prompt, the default username is `haiadmin`, and the password is the VM's Instance Id.
    - Once logged in, you see the Administrator dashboard:  
        <img src="/docs/images/01-gateway.png" width="600">
1. Click **ADD ROUTE**, and configure the new route with the following:
    - Give the **Route** and **Source** a unique name.
    - **Protocol:** TS Over SRT.
    - **Type:** Listener.
    - **Network Interface:** Auto.
    - **Port:** 5000
1. Scroll down, and click **ADD DESTINATION,** and configure the following:
    - Give the **Destination** a unique name.
    - **Protocol:** TS Over SRT.
    - **Type:** Listener.
    - **Network Interface:** Auto.
    - **Port:** 5001.
    - Scroll down and click **SAVE.**
1. Click **CREATE.** The route and destination are created.
1. Click the **START** icon and confirm the action. The route will initiate and the source will show a status of CONNECTING (yellow triangle), waiting for an input stream:  
  
    <img src="/docs/images/02-gateway.png" width="600">

## Create the Sender instance

The Sender instance will boot with a startup script that downloads example footage and streams it to the Gateway instance.

### Add project metadata

The Sender startup scripts reads pre-defined variables from project metadata to know where to send the stream.

1. In Cloud Shell, add variables to your Project Metadata:

    ```
    gcloud compute project-info add-metadata --metadata gateway_ip=[GATEWAY_IP_ADDRESS]
    gcloud compute project-info add-metadata --metadata sender_port=[SENDER_PORT]
    gcloud compute project-info add-metadata --metadata caller_port=[CALLER_PORT]
    ```

    Replace the following:

    -  `[GATEWAY_IP_ADDRESS]` is the internal IP address of the Gateway instance.
    -  `[SENDER_PORT]` is the port where the Gateway instance receives the SRT stream, which you configured to be 5000.
    -  `[CALLER_PORT]` is the port where the Caller instance retrieves the SRT stream. Set this to 5001.  

2. In Cloud Shell, copy the repo script `start-sender.sh` to your Cloud Storage bucket:  
  
    `gcloud storage cp scripts/start-sender.sh [BUCKET_NAME]`  

1. In Cloud Shell, create the Sender instance:
    ```
    gcloud compute instances create srt-sender-vm \
        --zone=[ZONE] \
        --machine-type=e2-standard-2 \
        --maintenance-policy=MIGRATE \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --image-project=ubuntu-os-cloud \
        --image-family=ubuntu-2204-lts \
        --boot-disk-size=100 \
        --boot-disk-type=pd-balanced \
        --network=default \
        --metadata=startup-script-url=gs://[BUCKET_NAME]/start-sender.sh
    ```
    Replace the following:

    -  `[ZONE]` is the same zone as the Gateway instance.
    -  `[BUCKET_NAME]` is the name of your script bucket created earlier.  

1. In the Gateway UI, click the **Statistics** icon under **Actions**. Once the Sender instance boots and the startup script runs, you should see a connection over port 5000 streaming data to the Gateway. This is your Sender instance streaming video content to the Gateway:  
  
    <img src="/docs/images/03-gateway.png" width="600">

## Create the Caller instance

1. In Cloud Shell, copy the repo script `start-caller.sh` to your Cloud Storage bucket:  
  
    `gcloud storage cp scripts/start-caller.sh [BUCKET_NAME]`  

1. Create the Caller instance:

    ```
    gcloud compute instances create srt-caller-vm \
        --zone=[ZONE] \
        --machine-type=n2d-standard-4 \
        --maintenance-policy=MIGRATE \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only \
        --image-project=ubuntu-os-cloud \
        --image-family=ubuntu-2204-lts \
        --boot-disk-size=200 \
        --boot-disk-type=pd-ssd \
        --network=default \
        --metadata=startup-script-url=gs://[BUCKET_NAME]/start-caller.sh
    ```

    Replace the following:

    -  `[ZONE]` is the same zone as the Gateway instance.
    -  `[BUCKET_NAME]` is the name of your script bucket created earlier.

Once the Caller instance is finished deploying, and the startup script runs, the Gateway UI will show a green checkbox under **Status:**

<img src="/docs/images/04-gateway.png" width="600">

You will also see the internal IP address of the Caller instance in the statistics panel:

<img src="/docs/images/05-gateway.png" width="600">

If you SSH into the Caller instance, you can see the chunks written to disk:

```
$ cd /tmp
$ ls -ltr
...
-rw-r--r-- 1 root root 3148436 May  1 17:45 streamChunk-20250501t174533-001099.ts
-rw-r--r-- 1 root root 2999540 May  1 17:45 streamChunk-20250501t174536-001100.ts
-rw-r--r-- 1 root root 2759840 May  1 17:45 streamChunk-20250501t174540-001101.ts
-rw-r--r-- 1 root root 4234512 May  1 17:45 streamChunk-20250501t174543-001102.ts
-rw-r--r-- 1 root root 2438548 May  1 17:45 streamChunk-20250501t174547-001103.ts
-rw-r--r-- 1 root root   61924 May  1 17:45 streamChunk.m3u8
```

## Security best practices

For simplicity, this tutorial doesn't follow security best practices, which can help prevent your project or resources from being compromised. Some easy and effective steps to take would be:

-  Eliminate external IP addresses for all instances.
    -  To create the Sender and Caller instances without an external IP address, use the `--no-address` flag during creation.
    -  To create the SRT Gateway instance without an external IP address, set **External IP** to **None** under the Network interfaces section of the UI.
    -  Communication with other instances in the same project can be achieved over internal IP addresses only.
-  Don't create additional firewall rules when you create the SRT Gateway instance.
-  Connect to the Gateway Administrator panel using an [IAP Tunnel](https://cloud.google.com/iap/docs/using-tcp-forwarding).

## Clean up

To avoid incurring charges to your Google Cloud account for the resources used in this tutorial, either delete the project that contains the resources, or keep the project and delete the individual resources.  

After you've finished the tutorial, clean up the resources you created on Google Cloud so you won't be billed for them in the future.

## What's next

-  [Haivision SRT Gateway Google Cloud Quick Start Guide](https://doc.haivision.com/HMG/4.0.1/google-cloud-quick-start-guide)