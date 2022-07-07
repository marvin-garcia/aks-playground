@description('Deployment Region')
param location string = resourceGroup().location

@description('Username for the Virtual Machine')
param adminUsername string = 'arcuser'

@description('RSA public key used for securing SSH access to ArcBox resources')
@secure()
param sshRSAPublicKey string

@description('The of Virtual Machines to deploy')
param vmCount int = 2

@description('The name prefix of you Virtual Machines')
param vmNamePrefix string = 'k3s'

@description('Arc Virtual Network Address Prefix')
param addressPrefix string = '172.16.0.0/16'

@description('Arc Virtual Network Subnet Address Prefix')
param arcSubnetAddressPrefix string = '172.16.1.0/24'

@description('Bastion Virtual Network Subnet Address Prefix')
param bastionSubnetAddressPrefix string = '172.16.3.64/26'
@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string

@description('Target GitHub account')
param githubAccount string = 'marvin-garcia'

@description('Target GitHub repository')
param githubRepo string = 'aks-playground'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/${githubRepo}/${githubBranch}/deployment/azure-arc/'
var privateIpBaseAddress = '${split(arcSubnetAddressPrefix, '.')[0]}.${split(arcSubnetAddressPrefix, '.')[1]}.${split(arcSubnetAddressPrefix, '.')[2]}'
var privateIpAddressStartCount = int(split(arcSubnetAddressPrefix, '.')[2]) + 4

module ubuntuRancherDeployment 'kubernetes/ubuntuRancher.bicep' = [for count in range(0, vmCount): {
  name: 'ubuntuRancherDeployment-${count + 1}'
  params: {
    adminUsername: adminUsername
    vmName: '${vmNamePrefix}-${count + 1}'
    privateIpAddress: '${privateIpBaseAddress}.${privateIpAddressStartCount + count}'
    sshRSAPublicKey: sshRSAPublicKey
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    deployBastion: deployBastion
    azureLocation: location
  }
}]

module stagingStorageAccountDeployment 'mgmt/mgmtStagingStorage.bicep' = {
  name: 'stagingStorageAccountDeployment'
  params: {
    location: location
  }
}

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    deployBastion: deployBastion
    location: location
    addressPrefix: addressPrefix
    arcSubnetAddressPrefix: arcSubnetAddressPrefix
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
  }
}

output arcBox array = [for count in range(0, vmCount): {
  id: ubuntuRancherDeployment[count].outputs.id
  vmName: '${vmNamePrefix}-${count + 1}'
  privateIpAddress: ubuntuRancherDeployment[count].outputs.privateIpAddress
  publicIpAddress: ubuntuRancherDeployment[count].outputs.publicIpAddress
}]
