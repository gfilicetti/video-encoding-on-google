| Previous: [Start the encoding workflow](03_start_the_encoding_workflow.md) |
|---:|

---

# Deploy Media CDN

This page walks you through the following procedures:

1. Enable the required services.
1. Deploy and configure Media CDN resources to serve your encoded video from a Cloud Storage bucket.
1. Configure the DNS settings of your custom domain.
1. Test whether a response is being cached, and validate the video stream works with a video player.

These steps can be found in more detail in [Set up a Media CDN Service](https://cloud.google.com/media-cdn/docs/quickstart), but the following instructions simplify those steps for our deployment.

## Enable the required services

To configure and deploy Media CDN services, you need to enable both the [Network Services API](https://cloud.google.com/service-infrastructure/docs/service-networking/getting-started) and the [Certificate Manager API](https://cloud.google.com/certificate-manager/docs/reference/certificate-manager/rest) for your project.

1. Enable the Network Services API:  
  
    ```
    gcloud services enable networkservices.googleapis.com
    ```

1. Enable the Certificate Manager API:  
  
    ```
    gcloud services enable certificatemanager.googleapis.com
    ```

## Create an EdgeCacheOrigin resource

Create an origin that points to your Cloud Storage bucket:

```bash
gcloud edge-cache origins create [ORIGIN] \
    --origin-address="[BUCKET]"
```

Replace the following:

-  `[ORIGIN]` is the name of a new origin.
-  `[BUCKET]` is the name of the primary bucket created during the previous step.

> [!NOTE]
> Media CDN can take up to 10 minutes to create the origin.

## Create an EdgeCacheService resource

Your `EdgeCacheService` resource configures routing, certificate, and caching settings, and can point to `EdgeCacheOrigin` resources.

1. In Cloud Shell, use a text editor to create a local file called `my-service.yaml`.
1. Paste the following sample content into the file, and then save it:

    ```yaml
    name: [SERVICE]
    routing:
    hostRules:
    - hosts:
        - [DOMAIN] 
        pathMatcher: routes
    pathMatchers:
    - name: routes
        routeRules:
        - priority: 1
        matchRules:
        - prefixMatch: /
        origin: [ORIGIN]
        routeAction:
            cdnPolicy:
            cacheMode: FORCE_CACHE_ALL
            defaultTtl: 3600s
        headerAction:
            responseHeadersToAdd:
            - headerName: "x-cache-status"
            headerValue: "{cdn_cache_status}"

    ```

    Replace the following:

    -  `[SERVICE]` is the name of the service.
    -  `[DOMAIN]` is the domain for the new service. You don't need to specify the protocol (e.g. `stream.example.com`).
    -  `[ORIGIN]` is the name of the `EdgeCacheOrigin` you created earlier.  

1. Import the `.yaml` file configuration to your edge-cache service:  
  
    ```bash
    gcloud edge-cache services import [SERVICE] \  
        --source=my-service.yaml
    ```

    Where `[SERVICE]` is the name of the service defined in the above `.yaml` file.

> [!NOTE]
> Media CDN can take up to 10 minutes to create the service. Media CDN provisions dedicated IP addresses and pushes your configuration to thousands of edge locations.

## Allow Service Account access to your bucket

You need to grant the Media CDN service account the `objectViewer` IAM permission on the Cloud Storage bucket you are using as your origin, as the bucket is not publicly accessible.  

The service account has the following format, and grants access only to Media CDN resources in the projects that you explicitly allow.

```bash
service-[PROJECT_NUM]@gcp-sa-mediaedgefill.iam.gserviceaccount.com
```

Where `[PROJECT_NUM]` is the Project Number.  

In Cloud Shell, run the following command:

```bash
gcloud storage buckets add-iam-policy-binding [BUCKET] \
    --member=serviceAccount:service-[PROJECT_NUM]@gcp-sa-mediaedgefill.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer
```

For more information, see [Configure private Cloud Storage buckets](https://cloud.google.com/media-cdn/docs/configure-origin#private-storage-buckets).

## Retrieve the IP addresses and assign to your domain

1. In Cloud Shell, use the following command to retrieve the IP address assigned to your service:  
  
    ```
    gcloud edge-cache services describe [SERVICE]
    ```
  
    Where `[SERVICE]` is the name of your service.  
  
    The output shows the IP addresses assigned to your service:

    ```bash
    ipv4Addresses:
        [IPV4_ADDRESS]
    ipv6Addresses:
        [IPV6_ADDRESS]
    name: projects/my-project/locations/global/edgeCacheServices/SERVICE
    ...
    ```

1. Assign the IP address to your domain using a domain record. In your domain management portal, add an `A RECORD` to your domain's DNS settings that points to the IPv4 address retrieved in the previous step.

## Test whether a response is being cached

To test that your service is correctly configured to cache content, use the `curl` command-line tool to issue requests and check the responses.  

In Cloud Shell, run the following command:

```bash
curl -svo /dev/null "http://[DOMAIN]/[FILE_NAME]"
```

Replace the following:

-  `[DOMAIN]` is the name of your domain or subdomain.
-  `[FILE_NAME]` is the name of the `.m3u8` file in your primary cloud bucket. You can list the bucket contents in Cloud Shell with `gcloud storage ls gs://[BUCKET_NAME]`.

For more information about understanding the cache states of the Media CDN, see [Test whether a response is being cached](https://cloud.google.com/media-cdn/docs/quickstart#test-caching).

## Use a media player to stream video

You can test the service by playing the video through a media player such as [VLC](https://www.videolan.org/vlc/) or [ffplay](https://ffmpeg.org/ffplay.html).

### VLC

Select **Open Network** and paste your domain URL into the URL field.

### ffplay

Run the following command on a local terminal:

```bash
ffplay http://[DOMAIN]/[FILE_NAME]
```

for example:

```bash
ffplay http://stream.example.com/liveEvent01.m3u8
```

# Optional: Clean up

To avoid incurring charges to your Google Cloud account for the resources used in this tutorial, either delete the project that contains the resources, or keep the project and delete the individual resources.  

After you've finished the tutorial, clean up the resources you created on Google Cloud so you won't be billed for them in the future.

### Delete all the components

1. Delete the Terraform deployment. In Cloud Shell:  
  
    ```bash
    cd terraform
    terraform destroy
    ```

1. Delete the **Haivision SRT Gateway** under [Solution Deployments](https://console.cloud.google.com/products/solutions/deployments).
1. [Delete the Camera instance](https://cloud.google.com/compute/docs/instances/stop-start-instance#delete_an_instance).
1. Delete the Media CDN resources you created:  
  
    ```bash
    gcloud edge-cache services delete [SERVICE]  
    gcloud edge-cache origins delete [ORIGIN]
    ```

1. [Delete the Cloud Storage buckets](https://cloud.google.com/storage/docs/deleting-buckets).
1. [Delete the firewall rules](https://cloud.google.com/vpc/docs/using-firewalls#deleting_firewall_rules).

### Delete the project

> [!CAUTION]
> Deleting a project has the following effects:
> -  Everything in the project is deleted. If you used an existing project for the tasks in this document, when you delete it, you also delete any other work you've done in the project.
> -  Custom project IDs are lost. When you created this project, you might have created a custom project ID that you want to use in the future. To preserve the URLs that use the project ID, such as an appspot.com URL, delete selected resources inside the project instead of deleting the whole project.  
> 1. In the Google Cloud console, go to the [Manage resources](https://console.cloud.google.com/iam-admin/projects) page.
> 1. In the project list, select the project that you want to delete, and then click **Delete**.
> 1. In the dialog, type the project ID, and then click **Shut down** to delete the project.

# What's next

-  Learn more about the [Haivision Media Gateway](https://doc.haivision.com/HMG/).
-  Learn more about the [Media CDN](https://cloud.google.com/media-cdn/docs/overview).

---
| Previous: [Start the encoding workflow](03_start_the_encoding_workflow.md) |
|---:|