targetScope = 'resourceGroup'

@description('Principal ID of the Function App managed identity')
param functionAppPrincipalId string

@description('Storage account name')
param storageAccountName string

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Computer Vision account name')
param computerVisionAccountName string

// Get references to existing resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: serviceBusNamespaceName
}

resource computerVision 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: computerVisionAccountName
}

// Storage Blob Data Contributor role for blob operations
module storageBlobContributor 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'storage-blob-contributor'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    resourceId: storageAccount.id
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor role for queue operations (if needed)
module storageQueueContributor 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'storage-queue-contributor'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    resourceId: storageAccount.id
    principalType: 'ServicePrincipal'
  }
}

// Azure Service Bus Data Receiver role for receiving messages
module serviceBusReceiver 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'servicebus-receiver'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Azure Service Bus Data Receiver
    resourceId: serviceBusNamespace.id
    principalType: 'ServicePrincipal'
  }
}

// Azure Service Bus Data Sender role for sending messages (if needed for dead letter handling)
module serviceBusSender 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'servicebus-sender'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39') // Azure Service Bus Data Sender
    resourceId: serviceBusNamespace.id
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services User role for Computer Vision access
module cognitiveServicesUser 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'cognitive-services-user'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    resourceId: computerVision.id
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Owner role for full blob access (required for Functions)
module storageBlobOwner 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'storage-blob-owner'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    resourceId: storageAccount.id
    principalType: 'ServicePrincipal'
  }
}

// Storage Table Data Contributor role for table operations
module storageTableContributor 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'storage-table-contributor'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    resourceId: storageAccount.id
    principalType: 'ServicePrincipal'
  }
}

// Monitoring Metrics Publisher role for Application Insights
module monitoringMetricsPublisher 'br/public:avm/ptn/authorization/role-assignment:0.1.1' = {
  name: 'monitoring-metrics-publisher'
  params: {
    principalId: functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb') // Monitoring Metrics Publisher
    resourceId: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}
