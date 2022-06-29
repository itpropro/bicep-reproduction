@description('Optional. The location to deploy the Web PubSub service.')
param location string = resourceGroup().location

@description('Required. The name of the Web PubSub resource.')
param name string

@description('Optional. Configuration Details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpoints array = []

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock.')
param lock string = ''

@description('Optional. Tags of the resource.')
param tags object = {}

@description('The unit count of the resource. 1 by default.')
param capacity int = 1

@allowed([
  'Free_F1'
  'Standard_S1'
])
@description('Optional. Pricing tier of App Configuration.')
param sku string = 'Free_F1'

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. When set as true, connection with AuthType=aad won\'t work.')
param disableAadAuth bool = false

@description('Optional. Disables all authentication methods other than AAD authentication.')
param disableLocalAuth bool = false

@description('Optional. Control permission for data plane traffic coming from public networks while private endpoint is enabled.')
param publicNetworkAccess string = 'Enabled'

@allowed([
  'ConnectivityLogs'
  'MessagingLogs'
])
@description('Optional. Control permission for data plane traffic coming from public networks while private endpoint is enabled.')
param resourceLogConfigurationsToEnable array = [
  'ConnectivityLogs'
  'MessagingLogs'
]

@description('Optional. Request client certificate during TLS handshake if enabled.')
param clientCertEnabled bool = false

@description('Optional. Networks ACLs, this value contains IPs to whitelist and/or Subnet information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls array = []

@description('Optional. Enable telemetry via the Customer Usage Attribution ID (GUID).')
param enableDefaultTelemetry bool = true

var resourceLogConfiguration = [for configuration in resourceLogConfigurationsToEnable: {
  name: configuration
  enabled: 'true'
}]

var identityType = systemAssignedIdentity ? 'SystemAssigned' : !empty(userAssignedIdentities) ? 'UserAssigned' : 'None'

var identity = {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
}

@description('Optional. Network ACLs for the resource. The values for the \'allow\' and \'deny\' array can be one or more of: ClientConnection, ServerConnection, RESTAPI.')
var webPubSubNetworkAcls = [for acl in networkAcls: {
  defaultAction: !empty(acl.defaultAction) ? contains([ 'Allow', 'Deny' ], acl.defaultAction) ? acl.defaultAction : 'Deny' : null
  publicNetwork: {
    allow: !empty(acl.allow) ? acl.allow : []
    deny: !empty(acl.deny) ? acl.deny : []
  }
}]

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

resource webPubSub 'Microsoft.SignalRService/webPubSub@2021-10-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    capacity: capacity
    name: sku
    tier: sku == 'Standard_S1' ? 'Standard' : 'Free'
  }
  identity: identity
  properties: {
    disableAadAuth: disableAadAuth
    disableLocalAuth: disableLocalAuth
    networkACLs: !empty(webPubSubNetworkAcls) ? {
    } : null
    publicNetworkAccess: publicNetworkAccess
    resourceLogConfiguration: {
      categories: resourceLogConfiguration
    }
    tls: {
      clientCertEnabled: clientCertEnabled
    }
  }
}

module webPubSub_privateEndpoints '../../Microsoft.Network/privateEndpoints/deploy.bicep' = [for (privateEndpoint, index) in privateEndpoints: {
  name: '${uniqueString(deployment().name, location)}-appConfiguration-PrivateEndpoint-${index}'
  params: {
    groupIds: [ privateEndpoint.service ]
    name: contains(privateEndpoint, 'name') ? privateEndpoint.name : 'pe-${last(split(webPubSub.id, '/'))}-${privateEndpoint.service}-${index}'
    serviceResourceId: webPubSub.id
    subnetResourceId: privateEndpoint.subnetResourceId
    location: reference(split(privateEndpoint.subnetResourceId, '/subnets/')[0], '2020-06-01', 'Full').location
    lock: contains(privateEndpoint, 'lock') ? privateEndpoint.lock : lock
    privateDnsZoneGroups: contains(privateEndpoint, 'privateDnsZoneGroups') ? privateEndpoint.privateDnsZoneGroups : []
    roleAssignments: contains(privateEndpoint, 'roleAssignments') ? privateEndpoint.roleAssignments : []
    tags: contains(privateEndpoint, 'tags') ? privateEndpoint.tags : {}
    manualPrivateLinkServiceConnections: contains(privateEndpoint, 'manualPrivateLinkServiceConnections') ? privateEndpoint.manualPrivateLinkServiceConnections : []
    customDnsConfigs: contains(privateEndpoint, 'customDnsConfigs') ? privateEndpoint.customDnsConfigs : []
  }
}]

resource webPubSub_lock 'Microsoft.Authorization/locks@2017-04-01' = if (!empty(lock)) {
  name: '${webPubSub.name}-${lock}-lock'
  properties: {
    level: any(lock)
    notes: lock == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'
  }
  scope: webPubSub
}
