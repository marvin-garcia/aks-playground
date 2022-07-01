@description('RSA public key used for securing SSH access to ArcBox resources')
@secure()
param sshRSAPublicKey string

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

var location = resourceGroup().location

module ubuntuRancherDeployment 'kubernetes/ubuntuRancher.bicep' = {
  name: 'ubuntuRancherDeployment'
  params: {
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
}

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
  }
}
