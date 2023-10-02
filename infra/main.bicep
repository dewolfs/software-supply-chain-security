targetScope = 'resourceGroup'

//*********************************
// PARAMETERS
//*********************************

param location string

//*********************************
// VARIABLES
//*********************************

var abbrs = loadJsonContent('abbreviations.json')

//*********************************
// CONTAINER REGISTRY
//*********************************

module containerRegistry 'modules/container-registry/registry/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-container-registry'
  scope: resourceGroup('rg-software-supply-chain-security')
  params: {
    name: '${abbrs.containerRegistryRegistries}weuscs001'
    location: location
    acrSku: 'Standard'
    roleAssignments: [
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d' //acrPull
        principalIds: [
          '${managedIdentity.properties.principalId}'
        ]
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

//*********************************
// MANAGED IDENTITY
//*********************************

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${abbrs.managedIdentityUserAssignedIdentities}${uniqueString(deployment().name, location)}'
  location: location
}

//*********************************
// KEYVAULT
//*********************************

module keyVault 'modules/key-vault/vault/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-keyvault'
  scope: resourceGroup('rg-software-supply-chain-security')
  params: {
    location: location
    name: '${abbrs.keyVaultVaults}${uniqueString(deployment().name, location)}1'
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
    vaultSku: 'standard'
    roleAssignments: [
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
        principalIds: [
          '9553b467-e3f3-429d-8285-0b5afd80b1d5' // GitHub workflow identity
        ]
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
        principalIds: [
          '59b8d021-d9ce-4799-83c0-a7a59f91ff06' // KeyVault Admins
        ]
        principalType: 'Group'
      }
    ]
  }
  dependsOn: [
    managedIdentity
  ]
}

//*********************************
// VIRTUAL NETWORK
//*********************************

module vnet 'modules/network/virtual-network/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-vnet'
  scope: resourceGroup('rg-software-supply-chain-security')
  params: {
    name: '${abbrs.networkVirtualNetworks}${uniqueString(deployment().name, location)}'
    location: location
    addressPrefixes: [
      '13.0.0.0/16'
    ]
    subnets: [
      {
        name: 'aks'
        addressPrefix: '13.0.0.0/24'
      }
    ]
  }
}

//*********************************
// KUBERNETES 
//*********************************

resource managedCluster 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' = {
  name: '${abbrs.containerServiceManagedClusters}${uniqueString(deployment().name, location)}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    agentPoolProfiles: [
      {
        count: 2
        mode: 'System'
        name: 'systempool'
        vmSize: 'Standard_DS2_v2'
        vnetSubnetID: vnet.outputs.subnetResourceIds[0]
      }
    ]
    dnsPrefix: 'sdjkljsd45454'
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
  }
}
