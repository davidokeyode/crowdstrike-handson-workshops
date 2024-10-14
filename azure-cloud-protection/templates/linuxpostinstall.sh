#!/bin/bash
apt-get -y update

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh

# Install Docker Compose
curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install kubectl
az aks install-cli

# Download and run images
docker pull sspreitzer/shellinabox:latest
docker run -d -p 4200:4200 -e SIAB_PASSWORD=password123 -e SIAB_SUDO=true sspreitzer/shellinabox:latest

# Install JQ
apt-get install jq -y
