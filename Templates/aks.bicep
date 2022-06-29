param location string = resourceGroup().location
param clusterName string
param clusterSku string = 'Basic'
param clusterTier string = 'Free'
param kubernetesVersion string = '1.22.6'
param vmSize string = 'Standard_B4ms'
param vmDiskSize int = 128
param minNodeCount int = 1
param maxNodeCount int = 2
param networkPlugin string = 'kubenet'
param podCidr string = '10.244.0.0/16'
param serviceCidr string = '10.10.0.0/24'
param dnsServiceIp string = '10.10.0.10'
param dockerBridgeAddress string = '172.17.0.1/16'
param nodepoolName string = 'nodepool1'
param adminUsername string = 'azureuser'
@secure()
param publicSshKey string
param virtualNetworkName string
param virtualNetworkPrefix array = [ '10.0.0.0/16' ]
param subnetName string = 'aks'
param subnetAddressPrefix string = '10.0.0.0/24'
param unique string = substring(uniqueString(resourceGroup().id), 0, 4)

var userIdentityName = '${clusterName}-${unique}-identity'
var workspaceName = '${clusterName}-${unique}-workspace'
var workspaceSku = 'pergb2018'

// User identity
resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: userIdentityName
  location: location
}

// Log Analytics workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: workspaceName
  location: location
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Emabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: 30
    sku: {
      name: workspaceSku
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

// Virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetworkPrefix
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}

// AKS cluster
resource managedCluster 'Microsoft.ContainerService/managedClusters@2022-05-02-preview' = {
  name: clusterName
  location: location
  sku: {
    name: clusterSku
    tier: clusterTier
  }
  identity: {
    type: 'UserAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${clusterName}-${unique}'
    agentPoolProfiles: [
      {
        name: nodepoolName
        count: minNodeCount
        vmSize: vmSize
        osDiskSizeGB: vmDiskSize
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        maxCount: maxNodeCount
        minCount: minNodeCount
        enableAutoScaling: true
        powerState: {
          code: 'Running'
        }
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        enableCustomCATrust: false
        mode: 'System'
        enableEncryptionAtHost: false
        enableUltraSSD: false
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableFIPS: false
      }
    ]
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: publicSshKey
          }
        ]
      }
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      ingressApplicationGateway: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspace.id
        }
      }
    }
    nodeResourceGroup: 'MC_aks_${clusterName}_${location}'
    enableRBAC: true
    networkProfile: {
      networkPlugin: networkPlugin
      loadBalancerSku: 'Standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
      }
      podCidr: podCidr
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIp
      dockerBridgeCidr: dockerBridgeAddress
      outboundType: 'loadBalancer'
      podCidrs: [
        podCidr
      ]
      serviceCidrs: [
        serviceCidr
      ]
      ipFamilies: [
        'IPv4'
      ]
    }
    identityProfile: {
      kubeletidentity: {
        resourceId: userIdentity.id
        clientId: userIdentity.properties.clientId
        objectId: userIdentity.properties.principalId
      }
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '10s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'false'
      'skip-nodes-with-system-pods': 'true'
    }
    disableLocalAccounts: false
    securityProfile: {}
    storageProfile: {
      diskCSIDriver: {
        enabled: true
        version: 'v1'
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: false
    }
  }
}
