@description('Azure region for the container registry.')
param location string

@description('Globally unique ACR name (alphanumeric only).')
@minLength(5)
@maxLength(50)
param acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrId string = acr.id
