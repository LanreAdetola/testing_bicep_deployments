@description('Azure region for the Key Vault.')
param location string

@description('Name of the Key Vault.')
param keyVaultName string

@description('Principal ID of the Container App managed identity.')
param containerAppPrincipalId string

@secure()
@description('Storage account key to store as a secret.')
param storageAccountKey string

@description('Optional: Object ID of a human admin for Key Vault Secrets Officer access.')
param adminObjectId string = ''

// Key Vault with RBAC authorization and soft-delete
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// Store the storage account key as a secret
resource storageSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storageAccountKey'
  properties: {
    value: storageAccountKey
  }
}

// Key Vault Secrets User role for the Container App managed identity
resource containerAppSecretsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, containerAppPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    )
    principalId: containerAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Optional: Key Vault Secrets Officer role for a human admin
resource adminSecretsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (adminObjectId != '') {
  name: guid(keyVault.id, adminObjectId, 'Key Vault Secrets Officer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
    )
    principalId: adminObjectId
    principalType: 'User'
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
