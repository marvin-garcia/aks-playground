param peeringName string
param virtualNetowrk1Id string
param virtualNetwork1AddressPrefix string
param virtualnetwork2Id string
param virtualNetwork2AddressPrefix string

resource vnet1Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-08-01' = {
  name: peeringName
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: true
    useRemoteGateways: false
    remoteAddressSpace: {
      addressPrefixes: [
        virtualNetwork1AddressPrefix
      ]
    }
    remoteVirtualNetwork: {
      id: virtualNetowrk1Id
    }
  }
}

resource vnet2Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-08-01' = {
  name: peeringName
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: true
    useRemoteGateways: false
    remoteAddressSpace: {
      addressPrefixes: [
        virtualNetwork2AddressPrefix
      ]
    }
    remoteVirtualNetwork: {
      id: virtualnetwork2Id
    }
  }
}
