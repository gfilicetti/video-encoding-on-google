Previous: [Create a virtual broadcast truck](02_create_virtual_broadcast_truck.md) | Next: [Deploy Media CDN](04_deploy_media_cdn.md)

---

# Start the encoding workflow

This page walks you through the following procedures:

1. Create a firewall rule to allow the GKE pods to reach the Gateway instance.
1. Start the encoding workflow using PubSub.
1. Validate the workflow is generating encoded chunks in Cloud Storage.

## Create a firewall rule

The GKE encoder pods access the truck's external IP address. Add a firewall rule to permit traffic over ports 5001 through 5010 to reach the Haivision VM.

1. In Cloud Shell, get the target tag assigned to the Haivision VM:  
  
    ```bash
    gcloud compute instances describe [NAME] --format="value(tags.items)"
    ```
    
    Where `[NAME]` is the name of your Haivision VM.  

1. Create a firewall rule that opens the required ports:

    ```bash
    gcloud compute firewall-rules create allow-srt \
        --action=ALLOW \
        --rules=udp:5001-5010 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=[TAG]
    ```

    Where `[TAG]` is the name of the target tag assigned to your Haivision VM.  

> [!NOTE]
> This firewall rule allows traffic from anywhere on the internet to access your Gateway instance. Always follow best practices for firewall rules to restrict traffic to your instance.

## Start the encoding workflow

You use Pub/Sub to launch the encoder workloads. This starts a live encoding from the virtual broadcast truck and writes the resulting segments to a new Cloud Storage bucket.  

Pub/Sub schema uses the Gateway VM's internal IP address for `truckOriginIp`, a unique event name as the `eventId`, and the `region` for the location of the streaming event.  

In Cloud Shell, run:

```bash
gcloud pubsub topics publish encoder-topic-[EVENT_ID] \
    --message='{"truckOriginIp": "[TRUCK_IP]", "eventId": "[EVENT_ID]", "region": "[REGION]"}'
```

Replace the following:

-  `[EVENT_ID]` is a unique name for a streaming event.
-  `[TRUCK_IP]` is the external IP address of the Gateway instance.
-  `[REGION]` is the same region as your GKE deployment.

> [!NOTE]
> The deployment can take between 3-5 minutes.

## Validating the encoding workflow

In the Gateway UI, click the **Statistics** icon under **Actions**. Once the GKE pod deployment is complete, you should see Destination connections over ports 5001 and 5002 from the Gateway. 

These show the encoder pods connected to the Gateway:  
  
<img src="/docs/images/05-gateway.png" width="600">

You can also verify encoded chunks of video are being written to Cloud Storage.

1. In Cloud Shell, list all Cloud Storage buckets:  
  
    ```
    gcloud storage ls
    ```

1. Note two buckets with the name template:  
  
    ```bash
    gs://[EVENT_ID]-primary/  
    gs://[EVENT_ID]-backup/
    ```

1. List the contents of either bucket:  
  
    ```bash
    gcloud storage ls gs://[EVENT_ID]-primary/  
    gs://[EVENT_ID]-primary/[EVENT_ID].m3u8  
    gs://[EVENT_ID]-primary/[EVENT_ID].000000.ts  
    gs://[EVENT_ID]-primary/[EVENT_ID].000001.ts  
    gs://[EVENT_ID]-primary/[EVENT_ID].000002.ts  
    gs://[EVENT_ID]-primary/[EVENT_ID].000003.ts  
    gs://[EVENT_ID]-primary/[EVENT_ID].000004.ts  
    ...
    ```

---
Previous: [Create a virtual broadcast truck](02_create_virtual_broadcast_truck.md) | Next: [Deploy Media CDN](04_deploy_media_cdn.md)