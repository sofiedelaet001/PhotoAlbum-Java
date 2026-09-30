@description('Name of the Container Apps managed environment.')
param environmentName string

@description('Name of the Container App.')
param containerAppName string

@description('Location for the Container Apps resources.')
param location string

@description('Tags to apply to the resources.')
param tags object = {}

@description('Resource ID of the Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Customer ID (workspace ID) of the Log Analytics workspace.')
param logAnalyticsCustomerId string

@description('Resource ID of the user-assigned managed identity.')
param userAssignedIdentityId string

@description('Client ID of the user-assigned managed identity.')
param userAssignedIdentityClientId string

@description('Login server of the Azure Container Registry.')
param containerRegistryLoginServer string

@description('Name of the Azure Container Registry.')
param containerRegistryName string

@description('Use ACR admin credentials for the registry connection instead of the managed identity. Fallback only.')
param useRegistryAdminCredentials bool = false

@description('Container image to deploy. Defaults to the Container Apps hello-world base image.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Port the container listens on.')
param targetPort int = 8080

@description('Name of the container inside the Container App.')
param containerName string = 'photoalbum'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: containerRegistryName
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: union(tags, {
    'azd-service-name': 'photoalbum'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      // No application secrets are required: the app authenticates to PostgreSQL
      // with the user-assigned managed identity (configured by Service Connector).
      // The registry password secret is only defined in the ACR admin fallback mode.
      secrets: useRegistryAdminCredentials ? [
        {
          name: 'acr-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ] : []
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        corsPolicy: {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
            'HEAD'
          ]
          allowedHeaders: [
            '*'
          ]
          exposeHeaders: [
            '*'
          ]
          maxAge: 3600
          allowCredentials: false
        }
      }
      registries: useRegistryAdminCredentials ? [
        {
          server: containerRegistryLoginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ] : [
        {
          server: containerRegistryLoginServer
          identity: userAssignedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerName
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: userAssignedIdentityClientId
            }
            {
              name: 'SERVER_PORT'
              value: string(targetPort)
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output environmentId string = managedEnvironment.id
output environmentName string = managedEnvironment.name
output containerAppId string = containerApp.id
output containerAppName string = containerApp.name
output containerName string = containerName
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output uri string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
