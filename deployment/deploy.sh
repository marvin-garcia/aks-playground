#!/bin/bash
clear
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHTGREEN='\033[1;32m'

unique=$(echo $RANDOM | md5sum | head -c 8)

printf "${LIGHTGREEN}Type the Azure region you wish to use (no spaces and all lowercase. i.e., 'westcentralus'):\n${NC}"
read location

resourceGroupName="aks-$unique"

clusterName="aks-$unique"
aksVnetName="aks-vnet-$unique"
aksVnetAddressPrefix='192.168.0.0/24'
aksSubnetName='aks'
aksSubnetAddressPrefix='192.168.0.0/24'
aksPodCidr='10.244.0.0/16'
aksServiceCidr='10.10.0.0/24'
aksDnsServiceIp='10.10.0.10'
aksDockerBridgeAddress='172.17.0.1/16'

appGwName="appgw-$unique"
appGwVnetName="appgw-vnet-$unique"
appGwPublicIpName="appgw-ip-$unique"
appGwPublicIpDomainNameLabel="aks-apps-$unique"
appGwVnetAddressPrefix='192.168.1.0/24'
appGwSubnetName='app-gw'
appGwSubnetAddressPrefix='192.168.1.0/24'

ingressPrivateIpAddress='192.168.0.230'
ingressClassName='ingress-test'

# Create resource group
az group create \
    -n $resourceGroupName \
    -l $location

# Deploy resources
deploymentName="aks-deployment-$unique"
az deployment group create \
    -g $resourceGroupName \
    --mode Incremental \
    --name $deploymentName \
    --template-file ./deployment/azuredeploy.bicep \
    --parameters clusterName=$clusterName \
    --parameters publicSshKey=@~/.ssh/id_rsa.pub \
    --parameters aksVirtualNetworkName=$aksVnetName \
    --parameters aksVirtualNetworkPrefix=$aksVnetAddressPrefix \
    --parameters aksSubnetName=$aksSubnetName \
    --parameters aksSubnetAddressPrefix=$aksSubnetAddressPrefix \
    --parameters podCidr=$aksPodCidr \
    --parameters serviceCidr=$aksServiceCidr \
    --parameters dnsServiceIp=$aksDnsServiceIp \
    --parameters dockerBridgeAddress=$aksDockerBridgeAddress \
    --parameters appGwName=$appGwName \
    --parameters appGwVirtualNetworkName=$appGwVnetName \
    --parameters appGwVirtualNetworkPrefix=$appGwVnetAddressPrefix \
    --parameters appGwSubnetName=$appGwSubnetName \
    --parameters appGwSubnetAddressPrefix=$appGwSubnetAddressPrefix \
    --parameters appGwPublicIpAddressName=$appGwPublicIpName \
    --parameters appGwPublicIpAddressDomainName=$appGwPublicIpDomainNameLabel \
    --parameters appGwBackendPoolIpAddress=$ingressPrivateIpAddress \
    --parameters unique=$unique

if [[ $? -gt 0 ]]
then
    exit 1
fi

# Get AKS credentials
clusterName=$(az aks list -g $resourceGroupName --query '[0].name' -o tsv)
az aks get-credentials \
    -g $resourceGroupName \
    -n $clusterName

if [[ $? -gt 0 ]]
then
    exit 1
fi

# Install NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade \
    ingress-nginx-test \
    ingress-nginx/ingress-nginx \
    --install \
    --create-namespace \
    --namespace 'ingress' \
    --set controller.service.loadBalancerIP=$ingressPrivateIpAddress \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true \
    --set controller.replicaCount=2 \
    --set controller.ingressClassByName=true \
    --set controller.ingressClassResource.enabled=true \
    --set controller.ingressClassResource.name=$ingressClassName \
    --set controller.ingressClassResource.controllerValue="k8s.io/$ingressClassName" \
    --wait

if [[ $? -gt 0 ]]
then
    exit 1
fi

# Install Apps
helm upgrade \
    car-api \
    ./CarApi/Helm/carapi \
    --install \
    --create-namespace \
    --namespace 'carapi' \
    -f ./CarApi/Helm/carapi/values.yaml

helm upgrade \
    user-api \
    ./UserApi/Helm/userapi \
    --install \
    --create-namespace \
    --namespace 'userapi' \
    -f ./UserApi/Helm/userapi/values.yaml

helm upgrade \
    console-api \
    ./ConsoleApi/Helm/consoleapi \
    --install \
    --create-namespace \
    --namespace 'consoleapi' \
    -f ./ConsoleApi/Helm/consoleapi/values.yaml


printf "${LIGHTGREEN}Deployment finished successfully.\n"
printf "${GREEN}Resource Group name: $resourceGroupName\n\n"

printf "${LIGHTGREEN}Navigate to the following URLs to test each app:\n\n"

printf "${GREEN}http://$appGwPublicIpDomainNameLabel.$location.cloudapp.azure.com/carapi/cars\n"
printf "${GREEN}http://$appGwPublicIpDomainNameLabel.$location.cloudapp.azure.com/userapi/users/1\n"
printf "${GREEN}http://$appGwPublicIpDomainNameLabel.$location.cloudapp.azure.com/consoleapi/consoles/2\n"

exit 0