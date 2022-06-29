param location string = resourceGroup().location
param applicationGatewayName string
param tier string = 'Standard_v2'
param skuSize string = 'Standard_v2'
param capacity int = 1
param zones array = []
param virtualNetworkName string
param virtualNetworkPrefix array = [ '10.1.0.0/16' ]
param subnetName string = 'app-gw'
param subnetAddressPrefix string = '10.1.0.0/24'
param publicIpAddressName string
param publicIpAddressDomainName string
param publicIpAddressSku string = 'Standard'
param publicIpAddressAllocationMethod string = 'Static'
param autoScaleMaxCapacity int = 2
param backendPoolIpAddress string
param backendAddressPoolName string = 'ingressBackend'
param backendHttpSettingName string = 'ingressSetting'
param frontendIpConfigurationName string = 'appGwPublicFrontendIp'
param gatewayIpConfigurationName string = 'appGatewayIpConfig'
param httpListenerName string = 'ingressListener'
param requestRoutingRuleName string = 'basic'

var frontendPortNumber = 80
var frontendPortName = 'port_${frontendPortNumber}'
var applicationGatewayId = resourceId('Microsoft.Network/applicationGateways', applicationGatewayName)
var requestRuleType = 'Basic'

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

// Public IP Address
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: publicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: publicIpAddressAllocationMethod
    dnsSettings: {
      domainNameLabel: publicIpAddressDomainName
    }
  }
  zones: zones
}

// App Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2021-08-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    autoscaleConfiguration: {
      minCapacity: capacity
      maxCapacity: autoScaleMaxCapacity
    }
    backendAddressPools: [
      {
        name: backendAddressPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: ''
              ipAddress: backendPoolIpAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingName
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
        name: frontendIpConfigurationName
        properties: {
          publicIPAddress: {
            id: publicIp.id
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
        name: gatewayIpConfigurationName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    httpListeners: [
      {
        name: httpListenerName
        properties: {
          frontendIPConfiguration: {
            id: '${applicationGatewayId}/frontendIPConfigurations/${frontendIpConfigurationName}'
          }
          frontendPort: {
            id: '${applicationGatewayId}/frontendPorts/${frontendPortName}'
          }
          protocol: 'Http'
        }
      }
    ]
    listeners: []
    requestRoutingRules: [
      {
        name: requestRoutingRuleName
        properties: {
          priority: 1
          ruleType: requestRuleType
          backendAddressPool: {
            id: '${applicationGatewayId}/backendAddressPools/${backendAddressPoolName}'
          }
          backendHttpSettings: {
            id: '${applicationGatewayId}/backendHttpSettingsCollection/${backendHttpSettingName}'
          }
          httpListener: {
            id: '${applicationGatewayId}/httpListeners/${httpListenerName}'
          }
        }
      }
    ]
    sku: {
      tier: tier
      name: skuSize
    }
  }
  zones: zones
}
