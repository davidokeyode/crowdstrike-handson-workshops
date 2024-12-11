
## Falcon Container Sensor for Linux on Azure Container Instances
* Runs inside each application container in a container group.
* Functionality is similar to that of the kernel-based Falcon sensor for Linux.
* It tracks activity in the application containers and sends telemetry to the Falcon Console. It generates detections and performs prevention operations for activity in those application containers.

## Prerequisites
* Linux system with Docker and Azure CLI installed

## Exercise 1 - Create an API Client Key
1. In the Falcon console, navigate to **Support and resources** → **Resources and tools** → **API clients and keys** → **Create API client**.
  - **Client name**: `falcon-serverless-sensor`
  - **Description**: API key for downloading the Falcon Serverless Sensor
  - **Permissions**:
    - Falcon Images Download: Read
    - Sensor Download: Read
  - Click **Create**.

2. Copy the **Client ID** and **Client Secret** to a secure location. You will need them later.

## Exercise 2 - Get Your CrowdStrike CID with Checksum
1. In the Falcon console, navigate to **Host setup and management** → **Deploy** → **Sensor downloads** → Copy the **CID**.

## Exercise 3 - Retrieve the Sensor Image and Push to ACR
1. **Run the following commands to get the sensor image path from the CrowdStrike container registry**.
  - Replace **`<YOUR_FALCON_CLIENT_ID>`**, **`<YOUR_FALCON_CLIENT_SECRET>`**, and **`<YOUR_CID>`** with the values that you obtained earlier.

  ```bash
  export FALCON_CLIENT_ID=<YOUR_FALCON_CLIENT_ID>
  export FALCON_CLIENT_SECRET=<YOUR_FALCON_CLIENT_SECRET>
  export FALCON_CID=<YOUR_CID>

  export LATESTSENSOR=$(bash <(curl -Ls https://github.com/CrowdStrike/falcon-scripts/releases/latest/download/falcon-container-sensor-pull.sh) -t falcon-container | tail -1) && echo $LATESTSENSOR
  ```

2. **Authenticate to your container registry**.
  - Replace **`<YOUR_ACR_FQDN>`**, **`<YOUR_ACR_USERNAME>`**, and **`<YOUR_ACR_PASSWORD>`** with your actual values.

  ```bash
  export ACR_FQDN=<YOUR_ACR_FQDN>
  export ACR_USERNAME=<YOUR_ACR_USERNAME>
  export ACR_PASSWORD=<YOUR_ACR_PASSWORD>
  export ACR_FALCON_REPO="falcon-container-sensor"

  docker login $ACR_FQDN -u $ACR_USERNAME -p $ACR_PASSWORD
  ```

3. **Tag the sensor image with the ACR name and push it to the registry**.
  ```bash
  docker tag $LATESTSENSOR $ACR_FQDN/$ACR_FALCON_REPO:latest
  docker push $ACR_FQDN/$ACR_FALCON_REPO:latest
  ```

## Exercise 4 - Run the Falcon Utility to Build a New Image
The Falcon utility, `falconutil`, is packaged within the Falcon Container sensor image.

* We can use it to patch an application container image with the Falcon Container sensor for Linux.
* We can also run it as part of a CI/CD process.
* The Falcon utility pulls both the application container image and Falcon Container sensor image from your registry.
* It uses Base64-encoded credentials from Docker’s `config.json` to authenticate the image registries.

1. **Authenticate to the registry that has the Falcon sensor image and the application image**.

  ```bash
  az login
  az acr login --name $ACR_FQDN
  az acr login --name $ACR_FQDN --expose-token
  ```

### Exercise 4a - Run the Falcon Utility to Build a New Image (Container Option)

* The new image size will be approximately **83MB** larger than the original image size.
  * **Original image size**: 274.6 MB
  * **New image size**: 357.6 MB

  ```bash
  RANDOM_NUMBER=$RANDOM
  export ACI_NAME="tomcat-webshell-p-$RANDOM_NUMBER"
  export ACI_GROUP_NAME="tomcat-webshell-p-$RANDOM_NUMBER"
  export ACI_RESOURCE_GROUP="azlab-rg"
  export ACI_SUB_ID=$(az account show --query id --output tsv)

  export ACR_FQDN=<ACR_FQDN>
  export ACR_APP_REPO=<ACR_APP_REPO>
  export ACR_APP_TAG=<ACR_APP_TAG>
  export ACR_APP_PROTECTED_REPO=<ACR_APP_PROTECTED_REPO>

  docker run --user 0:0 \
    -v ${HOME}/.docker/config.json:/root/.docker/config.json \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --rm $ACR_FQDN/$ACR_FALCON_REPO:latest \
    falconutil patch-image aci \
    --source-image-uri $ACR_FQDN/$ACR_APP_REPO:$ACR_APP_TAG \
    --target-image-uri $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG \
    --falcon-image-uri $ACR_FQDN/$ACR_FALCON_REPO:latest \
    --cid $FALCON_CID \
    --container $ACI_NAME \
    --container-group $ACI_GROUP_NAME \
    --resource-group $ACI_RESOURCE_GROUP \
    --subscription $ACI_SUB_ID

  # Push the new image to the registry
  docker push $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG
  ```

### Exercise 4b - Run the Falcon Utility to Build a New Image (Binary Option)

  ```bash
  RANDOM_NUMBER=$RANDOM
  export ACI_NAME="tomcat-webshell-p-$RANDOM_NUMBER"
  export ACI_GROUP_NAME="tomcat-webshell-p-$RANDOM_NUMBER"
  export ACI_RESOURCE_GROUP="azlab-rg"
  export ACI_SUB_ID=$(az account show --query id --output tsv)

  export ACR_FQDN=<ACR_FQDN>
  export ACR_APP_REPO=<ACR_APP_REPO>
  export ACR_APP_TAG=<ACR_APP_TAG>
  export ACR_APP_PROTECTED_REPO=<ACR_APP_PROTECTED_REPO>

  # Copy the Falcon utility from the Falcon Container image
  id=$(docker create $ACR_FQDN/$ACR_FALCON_REPO:latest)
  docker cp $id:/usr/bin/falconutil /tmp
  docker rm -v $id

  ls /tmp

  # Run the Falcon utility to patch the image
  /tmp/falconutil patch-image aci \
    --source-image-uri $ACR_FQDN/$ACR_APP_REPO:$ACR_APP_TAG \
    --target-image-uri $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG \
    --falcon-image-uri $ACR_FQDN/$ACR_FALCON_REPO:latest \
    --cid $FALCON_CID \
    --container $ACI_NAME \
    --container-group $ACI_GROUP_NAME \
    --resource-group $ACI_RESOURCE_GROUP \
    --subscription $ACI_SUB_ID

  docker push $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG
  ```

## Exercise 5 - Deploy Falcon Container Sensor for Linux to Azure Container Instances
* Create a container within a container group with this image.
* The container starts with a modified entrypoint that starts the Falcon Container sensor for Linux followed by the user-defined entrypoint.
* The values passed to the Azure Container Instances-specific flags (`--container`, `--container-group`, `--resource-group`, `--subscription`) must match the actual entities created in Azure Container Instances.
* Once running, your new container's basic details such as **pod name** and **Azure resource ID** will be visible on the Falcon console.
* Microsoft does not expose container metadata within Azure Container Instances. Falcon Container sensor for Linux offers optional use of public APIs to fetch additional container metadata such as image details, commands, and arguments. These APIs must be authenticated using user-assigned managed identities. If you want this added container visibility on the Falcon console, use option 2 (managed identity) for deploying the container group.

### Exercise 5a - Deploy the Container Group Using Azure CLI (Without Managed Identity)
  ```bash
  REGION=uksouth

  az group create --location $REGION --name $ACI_RESOURCE_GROUP

  az container create \
    --resource-group $ACI_RESOURCE_GROUP \
    --name $ACI_GROUP_NAME \
    --image $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --dns-name-label aci-demo-$RANDOM \
    --query ipAddress.fqdn

  az container create \
    --resource-group $ACI_RESOURCE_GROUP \
    --name $ACI_GROUP_NAME \
    --image $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --dns-name-label aci-demo-$RANDOM \
    --command-line "/opt/CrowdStrike/rootfs/bin/falcon-entrypoint <command>" \
    --query ipAddress.fqdn
  ```

### Exercise 5b - Deploy the Container Group Using Azure CLI (With Managed Identity)
  ```bash
  REGION=uksouth
  IDENTITY_NAME="$ACR_FQDN-$ACR_APP_PROTECTED_REPO-mi"

  az group create --location $REGION --name $ACI_RESOURCE_GROUP

  # Create a user-assigned managed identity
  az identity create --resource-group $ACI_RESOURCE_GROUP --name $IDENTITY_NAME

  # Store the resource ID and the service principal ID of the user-assigned identity
  ID=$(az identity show --resource-group $ACI_RESOURCE_GROUP --name $IDENTITY_NAME --query id --output tsv)
  SP=$(az identity show --resource-group $ACI_RESOURCE_GROUP --name $IDENTITY_NAME --query principalId --output tsv)

  # Assign a reader role for the user-assigned identity at the resource group scope
  az role assignment create --assignee-object-id $SP --role Reader --scope "/subscriptions/$ACI_SUB_ID/resourcegroups/$ACI_RESOURCE_GROUP"

  # Create a container group with the managed identity
  az container create \
    --resource-group $ACI_RESOURCE_GROUP \
    --name $ACI_GROUP_NAME \
    --image $ACR_FQDN/$ACR_APP_PROTECTED_REPO:$ACR_APP_TAG \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --dns-name-label aci-demo-$RANDOM \
    --assign-identity $ID \
    --ports 80 \
    --protocol TCP \
    --query ipAddress.fqdn
  ```

