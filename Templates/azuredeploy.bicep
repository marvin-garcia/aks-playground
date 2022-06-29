param location string = resourceGroup().location
param zones array = []

// Cluster params
param clusterNamePrefix string
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
param aksVirtualNetworkNamePrefix string
param aksVirtualNetworkPrefix string = '10.0.0.0/16'
param aksSubnetName string = 'aks'
param aksSubnetAddressPrefix string = '10.0.0.0/24'

// App Gateway params
param appGwNamePrefix string
param appGwTier string = 'Standard_v2'
param appGwSkuSize string = 'Standard_v2'
param appGwCapacity int = 1
param appGwVirtualNetworkNamePrefix string
param appGwVirtualNetworkPrefix string = '10.1.0.0/16'
param appGwSubnetName string = 'app-gw'
param appGwSubnetAddressPrefix string = '10.1.0.0/24'
param appGwPublicIpAddressNamePrefix string
param appGwPublicIpAddressDomainName string
param appGwPublicIpAddressSku string = 'Standard'
param appGwPublicIpAddressAllocationMethod string = 'Static'
param appGwAutoScaleMaxCapacity int = 2
param appGwBackendPoolIpAddress string
param appGwBackendAddressPoolName string = 'ingressBackend'
param appGwBackendHttpSettingName string = 'ingressSetting'
param appGwFrontendIpConfigurationName string = 'appGwPublicFrontendIp'
param appGwGatewayIpConfigurationName string = 'appGatewayIpConfig'
param appGwHttpListenerName string = 'ingressListener'
param appGwRequestRoutingRuleName string = 'basic'
param unique string = substring(uniqueString(resourceGroup().id), 0, 4)

var userIdentityName = 'aks-identity-${unique}'
var roleAssignmentId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7') // contributor role Id is 8e3af657-a8ff-443c-a75c-2fe8c4bcb635
var roleAssignmentName = guid(identity.id, roleAssignmentId, resourceGroup().id)
var clusterName = '${clusterNamePrefix}-${unique}'
var aksVirtualNetworkName = '${aksVirtualNetworkNamePrefix}-${unique}'
var appGwName = '${appGwNamePrefix}-${unique}'
var appGwVirtualNetworkName = '${appGwVirtualNetworkNamePrefix}-${unique}'
var appGwPublicIpAddressName = '${appGwPublicIpAddressNamePrefix}-${unique}'
var workspaceName = '${clusterName}-${unique}-workspace'
var workspaceSku = 'pergb2018'
var frontendPortNumber = 80
var frontendPortName = 'port_${frontendPortNumber}'
var appGwId = resourceId('Microsoft.Network/applicationGateways', appGwName)
var requestRuleType = 'Basic'
var vnetPeeringName = 'vnet-peering'

// User assigned identity
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
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

// AKS Virtual network
resource aksVnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: aksVirtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [aksVirtualNetworkPrefix]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetAddressPrefix
        }
      }
    ]
  }
}

// Contributor role assignment to user identity over ASK vnet
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: roleAssignmentName
  scope: aksVnet
  properties: {
    roleDefinitionId: roleAssignmentId
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
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
    userAssignedIdentities: {
      '${identity.id}': {}
    }
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
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', aksVirtualNetworkName, aksSubnetName)
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
    nodeResourceGroup: 'MC_aks_${clusterName}_${location}-${unique}'
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

// App GW Virtual network
resource appGwVnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: appGwVirtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ appGwVirtualNetworkPrefix ]
    }
    subnets: [
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetAddressPrefix
        }
      }
    ]
  }
}

// App GW Public IP Address
resource appGwPublicIp 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: appGwPublicIpAddressName
  location: location
  sku: {
    name: appGwPublicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: appGwPublicIpAddressAllocationMethod
    dnsSettings: {
      domainNameLabel: appGwPublicIpAddressDomainName
    }
  }
  zones: zones
}

// App Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2021-08-01' = {
  name: appGwName
  location: location
  properties: {
    autoscaleConfiguration: {
      minCapacity: appGwCapacity
      maxCapacity: appGwAutoScaleMaxCapacity
    }
    backendAddressPools: [
      {
        name: appGwBackendAddressPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: ''
              ipAddress: appGwBackendPoolIpAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: appGwBackendHttpSettingName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
        }
      }
    ]
    backendSettingsCollection: []
    frontendIPConfigurations: [
      {
        name: appGwFrontendIpConfigurationName
        properties: {
          publicIPAddress: {
            id: appGwPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: frontendPortNumber
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: appGwGatewayIpConfigurationName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', appGwVirtualNetworkName, appGwSubnetName)
          }
        }
      }
    ]
    httpListeners: [
      {
        name: appGwHttpListenerName
        properties: {
          frontendIPConfiguration: {
            id: '${appGwId}/frontendIPConfigurations/${appGwFrontendIpConfigurationName}'
          }
          frontendPort: {
            id: '${appGwId}/frontendPorts/${frontendPortName}'
          }
          protocol: 'Http'
        }
      }
    ]
    listeners: []
    requestRoutingRules: [
      {
        name: appGwRequestRoutingRuleName
        properties: {
          priority: 1
          ruleType: requestRuleType
          backendAddressPool: {
            id: '${appGwId}/backendAddressPools/${appGwBackendAddressPoolName}'
          }
          backendHttpSettings: {
            id: '${appGwId}/backendHttpSettingsCollection/${appGwBackendHttpSettingName}'
          }
          httpListener: {
            id: '${appGwId}/httpListeners/${appGwHttpListenerName}'
          }
        }
      }
    ]
    sku: {
      tier: appGwTier
      name: appGwSkuSize
    }
  }
  zones: zones
}

// AKS vnet peering
resource aksVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-08-01' = {
  name: vnetPeeringName
  parent: aksVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: true
    useRemoteGateways: false
    remoteAddressSpace: {
      addressPrefixes: [ appGwVirtualNetworkPrefix ]
    }
    remoteVirtualNetwork: {
      id: appGwVnet.id
    }
  }
}

// App GW vnet peering
resource appgwVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-08-01' = {
  name: vnetPeeringName
  parent: appGwVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: true
    useRemoteGateways: false
    remoteAddressSpace: {
      addressPrefixes: [ aksVirtualNetworkPrefix ]
    }
    remoteVirtualNetwork: {
      id: aksVnet.id
    }
  }
}
