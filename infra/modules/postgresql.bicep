@description('Name of the Azure Database for PostgreSQL flexible server.')
param name string

@description('Location for the PostgreSQL flexible server.')
param location string

@description('Tags to apply to the resource.')
param tags object = {}

@description('Name of the application database to create.')
param databaseName string

@description('Administrator login name for the PostgreSQL flexible server.')
param administratorLogin string

@description('Administrator password for the PostgreSQL flexible server.')
@secure()
param administratorLoginPassword string

@description('SKU name for the PostgreSQL flexible server.')
param skuName string = 'Standard_B1ms'

@description('SKU tier for the PostgreSQL flexible server.')
param skuTier string = 'Burstable'

@description('Storage size in GB.')
param storageSizeGB int = 32

@description('PostgreSQL major version.')
param postgresVersion string = '17'

@description('Object ID of the Microsoft Entra administrator for the server.')
param entraAdminObjectId string

@description('Principal name (UPN or app name) of the Microsoft Entra administrator.')
param entraAdminName string

@description('Principal type of the Microsoft Entra administrator.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param entraAdminType string = 'User'

@description('Tenant ID for Microsoft Entra authentication.')
param tenantId string = subscription().tenantId

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    authConfig: {
      // Managed identity (Entra) authentication is the secure path used by the app.
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: tenantId
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// Allow traffic from Azure services (0.0.0.0).
resource allowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: postgresServer
  name: 'AllowAllAzureServicesAndResources'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Microsoft Entra administrator, required so Service Connector can create the
// passwordless (managed identity) database role for the container app.
resource entraAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  parent: postgresServer
  name: entraAdminObjectId
  properties: {
    principalType: entraAdminType
    principalName: entraAdminName
    tenantId: tenantId
  }
  dependsOn: [
    allowAzureServices
  ]
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
  dependsOn: [
    entraAdmin
  ]
}

output id string = postgresServer.id
output name string = postgresServer.name
output fqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
