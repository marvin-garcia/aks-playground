param location string = resourceGroup().location
param zones array = []

// Cluster params
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
param aksVirtualNetworkName string
param aksVirtualNetworkPrefix string = '10.0.0.0/16'
param aksSubnetName string = 'aks'
param aksSubnetAddressPrefix string = '10.0.0.0/24'

// App Gateway params
param applicationGatewayName string
param appGwTier string = 'Standard_v2'
param appGwSkuSize string = 'Standard_v2'
param appGwCapacity int = 2
param appGwVirtualNetworkName string
param appGwVirtualNetworkPrefix string = '10.1.0.0/16'
param appGwSubnetName string = 'app-gw'
param appGwSubnetAddressPrefix string = '10.1.0.0/24'
param appGwPublicIpAddressName string
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

// Repo params
param repoOrgName string = 'marvin-garcia'
param repoName string = 'aks-playground'
param repoBranchName string = 'main'

param unique string = substring(uniqueString(resourceGroup().id), 0, 4)

var aksDeploymentName = 'aksDeployment-${unique}'
var appGwDeploymentName = 'appGwDeployment-${unique}'
var vnetPeeringDeploymentName = 'vnetPeering-${unique}'
var appGwTemplateLink = 'https://raw.githubusercontent.com/$repoOrgName/$repoName/$repoBranchName/Templates/app-gw.bicep'
var aksTemplateLink = 'https://raw.githubusercontent.com/$repoOrgName/$repoName/$repoBranchName/Templates/aks.bicep'
var vnetPeeringName = 'vnet-peering'
var vnetPeeringTemplateLink = 'https://raw.githubusercontent.com/$repoOrgName/$repoName/$repoBranchName/Templates/vnet-peering.bicep'

resource appGwdeployment 'Microsoft.Resources/deployments@2021-04-01' = {
  name: appGwDeploymentName
  location: location
  properties: {
    debugSetting: {
      detailLevel: 'Debug'
    }
    mode: 'Incremental'
    parameters: {
      applicationGatewayName: applicationGatewayName
      tier: appGwTier
      skuSize: appGwSkuSize
      capacity: appGwCapacity
      zones: zones
      appGwVirtualNetworkName: appGwVirtualNetworkName
      appGwVirtualNetworkPrefix: [appGwVirtualNetworkPrefix]
      appGwSubnetName: appGwSubnetName
      appGwSubnetAddressPrefix: appGwSubnetAddressPrefix
      publicIpAddressName: appGwPublicIpAddressName
      publicIpAddressDomainName: appGwPublicIpAddressDomainName
      publicIpAddressSku: appGwPublicIpAddressSku
      publicIpAddressAllocationMethod: appGwPublicIpAddressAllocationMethod
      autoScaleMaxCapacity: appGwAutoScaleMaxCapacity
      backendPoolIpAddress: appGwBackendPoolIpAddress
      backendAddressPoolName: appGwBackendAddressPoolName
      backendHttpSettingName: appGwBackendHttpSettingName
      frontendIpConfigurationName: appGwFrontendIpConfigurationName
      gatewayIpConfigurationName: appGwGatewayIpConfigurationName
      httpListenerName: appGwHttpListenerName
      requestRoutingRuleName: appGwRequestRoutingRuleName
    }
    templateLink: {
      uri: appGwTemplateLink
    }
  }
}

// resource aksdeployment 'Microsoft.Resources/deployments@2021-04-01' = {
//   name: aksDeploymentName
//   location: location
//   properties: {
//     debugSetting: {
//       detailLevel: 'Debug'
//     }
//     mode: 'Incremental'
//     parameters: {
//       clusterName: clusterName
//       clusterSku: clusterSku
//       clusterTier: clusterTier
//       kubernetesVersion: kubernetesVersion
//       vmSize: vmSize
//       vmDiskSize: vmDiskSize
//       minNodeCount: minNodeCount
//       maxNodeCount: maxNodeCount
//       networkPlugin: networkPlugin
//       podCidr: podCidr
//       serviceCidr: serviceCidr
//       dnsServiceIp: dnsServiceIp
//       dockerBridgeAddress: dockerBridgeAddress
//       nodepoolName: nodepoolName
//       adminUsername: adminUsername
//       publicSshKey: publicSshKey
//       aksVirtualNetworkName: aksVirtualNetworkName
//       aksVirtualNetworkPrefix: [aksVirtualNetworkPrefix]
//       aksSubnetName: aksSubnetName
//       aksSubnetAddressPrefix: aksSubnetAddressPrefix
//     }
//     templateLink: {
//       uri: aksTemplateLink
//     }
//   }
// }

// resource vnetPeeringDeployment 'Microsoft.Resources/deployments@2021-04-01' = {
//   name: vnetPeeringDeploymentName
//   location: location
//   dependsOn: [
//     appGwdeployment
//     aksdeployment
//   ]
//   properties: {
//     mode: 'Incremental'
//     parameters: {
//       peeringName: vnetPeeringName
//       virtualNetowrk1Id: resourceId('Microsoft.Network/virtualNetworks', appGwVirtualNetworkName)
//       virtualNetwork1AddressPrefix: appGwVirtualNetworkPrefix
//       virtualnetwork2Id: resourceId('Microsoft.Network/virtualNetworks', aksVirtualNetworkName)
//       virtualNetwork2AddressPrefix: aksVirtualNetworkPrefix
//     }
//     templateLink: {
//       uri: vnetPeeringTemplateLink
//     }
//   }
// }
