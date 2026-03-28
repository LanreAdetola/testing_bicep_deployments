// main.bicep

@description('Location for the storage account.')
param location string = resourceGroup().location

@description('Unique name for the storage account.')
@minLength(3)
@maxLength(24)
param storageName string = 'stg${uniqueString(resourceGroup().id)}'

@description('Name of key vault')
param keyVaultName string = 'kv-${uniqueString(resourceGroup().id)}'

param objectId string

// ---storage account---
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

// ---key vault---
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' ={
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: objectId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
      }
    ]
  }
}

// ---store the storage key as a secret in the key vault---
resource storageSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storageAccountKey'
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}


output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output secretName string = storageSecret.name
