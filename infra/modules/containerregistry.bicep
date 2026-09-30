@description('Name of the Azure Container Registry.')
param name string

@description('Location for the Azure Container Registry.')
param location string

@description('Tags to apply to the resource.')
param tags object = {}

@description('Principal ID of the user-assigned managed identity that needs AcrPull access.')
param acrPullPrincipalId string

@description('Create the AcrPull role assignment. Set to false only when the deploying principal lacks Microsoft.Authorization/roleAssignments/write.')
param assignAcrPullRole bool = true

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    // Admin user is only enabled when the managed-identity (AcrPull) path is unavailable.
    adminUserEnabled: !assignAcrPullRole
    publicNetworkAccess: 'Enabled'
    anonymousPullEnabled: false
    zoneRedundancy: 'Disabled'
  }
}

// MANDATORY: AcrPull role assignment for the user-assigned managed identity.
// Declared before the Container App so the pull permission exists first.
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignAcrPullRole) {
  name: guid(containerRegistry.id, acrPullPrincipalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: acrPullPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
output acrPullRoleAssignmentId string = assignAcrPullRole ? acrPullRoleAssignment.id : ''
output adminUserEnabled bool = !assignAcrPullRole
