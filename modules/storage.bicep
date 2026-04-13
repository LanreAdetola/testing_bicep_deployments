@description('Azure region for the storage account.')
param location string

@description('Globally unique storage account name.')
@minLength(3)
@maxLength(24)
param storageName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id

@secure()
output storageAccountKey string = storageAccount.listKeys().keys[0].value
