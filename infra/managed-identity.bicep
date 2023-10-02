targetScope = 'resourceGroup'

//*********************************
// PARAMETERS
//*********************************

param location string

param aksClusterName string

param UAIName string

//*********************************
// VARIABLES
//*********************************

var ratifyNamespace = 'gatekeeper-system'
var ratifyServiceAccount = 'ratify-admin'

//*********************************
// EXISTING AKS CLUSTER
//*********************************

resource existingAKS 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' existing = {
  name: aksClusterName
  scope: resourceGroup('rg-software-supply-chain-security')
}

//*********************************
// EXISTING MANAGED IDENTITY
//*********************************

resource existingUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: UAIName
  scope: resourceGroup('rg-software-supply-chain-security')
}

//*********************************
// MANAGED IDENTITY
//*********************************

module managedIdentity 'modules/managed-identity/user-assigned-identity/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-user-managed-identity'
  scope: resourceGroup('rg-software-supply-chain-security')
  params: {
    name: existingUAI.name
    location: location
    federatedIdentityCredentials: [
      {
        audiences: [
          'api://AzureADTokenExchange'
        ]
        issuer: existingAKS.properties.oidcIssuerProfile.issuerURL
        name: 'ratify-federated-credential'
        subject: 'system:serviceaccount:${ratifyNamespace}:${ratifyServiceAccount}'
      }
    ]
  }
}
