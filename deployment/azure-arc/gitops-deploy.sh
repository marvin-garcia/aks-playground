#!/bin/bash

resourceGroupName="arc-jumpstart"
clusterName="ArcBox-K3s"

az k8s-configuration flux create \
    -g $resourceGroupName \
    -c $clusterName \
    -n cluster-config \
    --namespace cluster-config \
    -t connectedClusters \
    --scope cluster \
    -u https://github.com/marvin-garcia/aks-playground \
    --branch main \
    --kustomization name=infra path=./infrastructure prune=true

# az k8s-configuration flux create \
#     -g $resourceGroupName \
#     -c $clusterName \
#     -n apps-config \
#     --namespace cluster-config \
#     -t connectedClusters \
#     --scope cluster \
#     -u https://github.com/marvin-garcia/aks-playground \
#     --branch main \
#     --kustomization name=apps path=./apps prune=true
