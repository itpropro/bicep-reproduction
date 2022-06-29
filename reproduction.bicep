targetScope = 'subscription'
param prefix string = 'testingbicep'
param location string = 'westeurope'
param dateTime string = utcNow()

var environments = [
  'prod'
  'dev'
]

module resourceGroups 'modules/carml/0.6.0/Microsoft.Resources/resourceGroups/deploy.bicep' = [for environment in environments: {
  name: '${format('{0}-{1}', prefix, environment)}-${uniqueString(dateTime)}'
  params: {
    name: format('{0}-{1}', prefix, environment)
    location: location
    enableDefaultTelemetry: false
  }
}]

module functionStorage 'modules/carml/0.6.0/Microsoft.Storage/storageAccounts/deploy.bicep' = [for environment in environments: {
  scope: resourceGroup(format('{0}-{1}', prefix, environment))
  name: '${substring(format('{0}function{1}{2}', prefix, 'storage', environment), 0, length(format('{0}function{1}{2}', prefix, 'storage', environment)) >= 24 ? 24 : length(format('{0}function{1}{2}', prefix, 'storage', environment)))}-${uniqueString(dateTime)}'
  params: {
    name: substring(format('{0}function{1}{2}', prefix, 'storage', environment), 0, length(format('{0}function{1}{2}', prefix, 'storage', environment)) >= 24 ? 24 : length(format('{0}function{1}{2}', prefix, 'storage', environment)))
    location: location
    storageAccountKind: 'StorageV2'
    storageAccountSku: 'Standard_LRS'
    enableDefaultTelemetry: false
  }
  dependsOn: [ resourceGroups ]
}]

module functionHostingPlan 'modules/carml/0.6.0/Microsoft.Web/serverfarms/deploy.bicep' = [for environment in environments: {
  scope: resourceGroup(format('{0}-{1}', prefix, environment))
  name: '${format('{0}-api-plan-{1}', prefix, environment)}-${uniqueString(dateTime)}'
  params: {
    name: format('{0}-api-plan-{1}', prefix, environment)
    location: location
    sku: {
      name: 'Y1'
      tier: 'Dynamic'
    }
    enableDefaultTelemetry: false
  }
  dependsOn: [ resourceGroups ]
}]

module function 'modules/carml/0.6.0/Microsoft.Web/sites/deploy.bicep' = [for (environment, index) in environments: {
  scope: resourceGroup(format('{0}-{1}', prefix, environment))
  name: '${format('{0}-function-{1}', prefix, environment)}-${uniqueString(dateTime)}'
  params: {
    name: format('{0}-function-{1}', prefix, environment)
    location: location
    kind: 'functionapp'
    systemAssignedIdentity: true
    serverFarmResourceId: functionHostingPlan[index].outputs.resourceId
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage[index].outputs.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId(subscription().subscriptionId, format('{0}-{1}', prefix, environment), 'Microsoft.Storage/storageAccounts', substring(format('{0}function{1}{2}', prefix, 'storage', environment), 0, length(format('{0}function{1}{2}', prefix, 'storage', environment)) >= 24 ? 24 : length(format('{0}function{1}{2}', prefix, 'storage', environment)))), '2021-09-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage[index].outputs.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId(subscription().subscriptionId, format('{0}-{1}', prefix, environment), 'Microsoft.Storage/storageAccounts', substring(format('{0}function{1}{2}', prefix, 'storage', environment), 0, length(format('{0}function{1}{2}', prefix, 'storage', environment)) >= 24 ? 24 : length(format('{0}function{1}{2}', prefix, 'storage', environment)))), '2021-09-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(format('{0}-api-function-{1}', prefix, environment))
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~16'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
      ]
    }
    enableDefaultTelemetry: false
  }
  dependsOn: [
    functionStorage
    functionHostingPlan
    resourceGroups
  ]
}]
