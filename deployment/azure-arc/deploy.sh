#!/bin/bash
clear
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHTGREEN='\033[1;32m'

echo -e "\n$(tput setaf 2)Type the Azure region you wish to use (no spaces and all lowercase. i.e., 'westcentralus'): $(tput setaf 7)"
read location

echo -e "\n$(tput setaf 2)How many Rancher k3s cluster VMs do you want to create? $(tput setaf 7)"
read vmCount

unique=$(echo $RANDOM | md5sum | head -c 8)
vmNamePrefix="k3s-$unique"
workspaceName="workspace-$unique"
addressPrefix="172.16.0.0/16"
arcSubnetAddressPrefix="172.16.1.0/24"
bastionSubnetAddressPrefix="172.16.3.64/26"

remote=$(git config --get remote.origin.url)
repoUrl=$(echo ${remote//".git"})
repoBranch=$(git rev-parse --abbrev-ref HEAD)

account=$(az account show)
tenantId=$(echo $account | jq -r ".tenantId")
subscriptionId=$(echo $account | jq -r ".id")

# Create resource group
resourceGroupName="arc-k8s-$repoBranch-$unique"
az group create \
    -n $resourceGroupName \
    -l $location \
    -o none

# Create service principal
spnName="arc-k8s-$unique"
az ad sp create-for-rbac -n $spnName --role "Contributor" --scopes /subscriptions/$subscriptionId -o none
az ad sp create-for-rbac -n $spnName --role "Security admin" --scopes /subscriptions/$subscriptionId -o none
spn=$(az ad sp create-for-rbac -n $spnName --role "Security reader" --scopes /subscriptions/$subscriptionId -o tsv --query "[appId, password]")
spnClientId=$(echo $spn | awk '{print $1;}')
spnPassword=$(echo $spn | awk '{print $2;}')

# Deploy resources
deploymentName="arc-k8s-$repoBranch-$unique"
echo -e "\n$(tput setaf 2)Creating deployment $deploymentName$(tput setaf 7)"

output=$(az deployment group create \
    -g $resourceGroupName \
    --mode Incremental \
    --name $deploymentName \
    --template-file ./deployment/azure-arc/bicep/azuredeploy.bicep \
    --parameters location=$location \
    --parameters sshRSAPublicKey=@~/.ssh/id_rsa.pub \
    --parameters vmCount=$vmCount \
    --parameters vmNamePrefix=$vmNamePrefix \
    --parameters addressPrefix=$addressPrefix \
    --parameters arcSubnetAddressPrefix=$arcSubnetAddressPrefix \
    --parameters spnClientId=$spnClientId \
    --parameters spnClientSecret=$spnPassword \
    --parameters spnTenantId=$tenantId \
    --parameters logAnalyticsWorkspaceName=$workspaceName \
    --parameters githubBranch=$repoBranch \
    --parameters deployBastion=true \
    --query 'properties.outputs' -o json)

if [[ $? -gt 0 ]]
then
    exit 1
fi

for (( c=0; c<$vmCount; c++))
do
    vm=$(echo $output | jq -r ".arcBox.value[$c]")
    vmName=$(echo $vm | jq -r ".vmName")
    ipAddress=$(echo $vm | jq -r ".privateIpAddress")

    rm -rf "./infrastructure/$vmName"

    echo -e "\n$(tput setaf 2)Creating cluster infrastructure folder for '$vmName'\n$(tput setaf 7)"

    mkdir -p "./infrastructure/$vmName"
    
    echo -e "\n$(tput setaf 2)Writing cluster's kustomization file for '$vmName'\n$(tput setaf 7)"
    
    ## Write cluster's custom ingress release
    cat << EOF > "./infrastructure/$vmName/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../ingress-nginx
patchesStrategicMerge:
  - values.yaml
EOF

    echo -e "\n$(tput setaf 2)Writing cluster's values file for '$vmName'\n$(tput setaf 7)"
    
    cat << EOF > "./infrastructure/$vmName/values.yaml"
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: cluster-config
spec:
  chart:
    spec:
      chart: ingress-nginx
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: cluster-config
  values:
    controller:
      service:
        type: LoadBalancer
        externalIPs:
        - '$ipAddress'
EOF

    echo -e "\n$(tput setaf 2)Pushing infrastructure files to repo for '$vmName'\n$(tput setaf 7)"

    git add "./infrastructure/$vmName"
    git commit -m "Added infrastructure files for '$vmName'"
    git push

    if [[ $? -gt 0 ]]
    then
        exit 1
    fi

    echo -e "\n$(tput setaf 2)Starting GitOps configuration for cluster '$vmName'$(tput setaf 7)"

    ## Create cluster's Flux configurations
    az k8s-configuration flux create \
      -g $resourceGroupName \
      -c $vmName \
      -n sources \
      -t connectedClusters \
      -u $repoUrl \
      --branch $repoBranch \
      --kustomization name=sources path=./sources prune=true \
      --namespace cluster-config \
      --scope cluster \
      -o none

    if [[ $? -gt 0 ]]
    then
        exit 1
    fi

    az k8s-configuration flux create \
      -g $resourceGroupName \
      -c $vmName \
      -n infra \
      -t connectedClusters \
      -u $repoUrl \
      --branch $repoBranch \
      --kustomization name=infra path=./infrastructure/$vmName prune=true \
      --namespace cluster-config \
      --scope cluster \
      -o none

    if [[ $? -gt 0 ]]
    then
        exit 1
    fi

    az k8s-configuration flux create \
      -g $resourceGroupName \
      -c $vmName \
      -n apps \
      -t connectedClusters \
      -u $repoUrl \
      --branch $repoBranch \
      --kustomization name=redis path=./infrastructure/redis prune=true \
      --kustomization name=apps path=./apps prune=true dependsOn=["redis"] \
      --namespace cluster-config \
      --scope cluster \
      --interval 3m \
      --timeout 3m \
      -o none

    if [[ $? -gt 0 ]]
    then
        exit 1
    fi
done

echo -e "\n$(tput setaf 2)Deployment finished successfully$(tput setaf 7)"
echo -e "$(tput setaf 2)Resource Group name: $resourceGroupName$(tput setaf 7)"

echo -e "$(tput setaf 2)\nCluster(s) public endpoints:$(tput setaf 7)"
for (( c=0; c<$vmCount; c++))
do
    vm=$(echo $output | jq -r ".arcBox.value[$c]")
    vmName=$(echo $vm | jq -r ".vmName")

    echo -e "$(tput setaf 2)http://$vmName.$location.cloudapp.azure.com/$(tput setaf 7)"
done

exit 0