targetScope = 'resourceGroup'

// ──────────────────────────────────────────────
// Parameters
// ──────────────────────────────────────────────

@description('Environment name used as prefix/suffix for all resources (e.g. dev, staging, prod).')
param environmentName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Optional: AAD object ID of a human admin for Key Vault Secrets Officer access.')
param adminObjectId string = ''

// ──────────────────────────────────────────────
// Derived resource names
// ──────────────────────────────────────────────

var suffix = uniqueString(resourceGroup().id)
var storageName = take('st${replace(environmentName, '-', '')}${suffix}', 24)
var keyVaultName = take('kv-${environmentName}-${suffix}', 24)
var acrName = take('acr${replace(environmentName, '-', '')}${suffix}', 50)
var containerAppName = 'ca-${environmentName}'

// ──────────────────────────────────────────────
// Modules — independent (deploy in parallel)
// ──────────────────────────────────────────────

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalytics'
  params: {
    location: location
    environmentName: environmentName
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageName: storageName
  }
}

module acr 'modules/container-registry.bicep' = {
  name: 'acr'
  params: {
    location: location
    acrName: acrName
  }
}

// ──────────────────────────────────────────────
// Modules — dependent on log-analytics
// ──────────────────────────────────────────────

module containerApps 'modules/container-apps.bicep' = {
  name: 'containerApps'
  params: {
    location: location
    environmentName: environmentName
    containerAppName: containerAppName
    logAnalyticsCustomerId: logAnalytics.outputs.workspaceCustomerId
    logAnalyticsSharedKey: logAnalytics.outputs.workspaceSharedKey
  }
}

// ──────────────────────────────────────────────
// Modules — dependent on container-apps / storage
// ──────────────────────────────────────────────

module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVault'
  params: {
    location: location
    keyVaultName: keyVaultName
    containerAppPrincipalId: containerApps.outputs.containerAppPrincipalId
    storageAccountKey: storage.outputs.storageAccountKey
    adminObjectId: adminObjectId
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    containerAppId: containerApps.outputs.containerAppId
    containerAppName: containerAppName
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────

output acrLoginServer string = acr.outputs.acrLoginServer
output containerAppUrl string = containerApps.outputs.containerAppUrl
output keyVaultName string = keyVault.outputs.keyVaultName
output storageAccountName string = storage.outputs.storageAccountName
