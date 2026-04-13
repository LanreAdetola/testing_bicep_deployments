@description('Azure region for the workspace.')
param location string

@description('Environment name used as resource suffix.')
param environmentName string

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${environmentName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output workspaceId string = workspace.id
output workspaceCustomerId string = workspace.properties.customerId

@description('Primary shared key for Container Apps log ingestion.')
@secure()
output workspaceSharedKey string = workspace.listKeys().primarySharedKey
