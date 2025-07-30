targetScope = 'resourceGroup'

@description('The environment name for all resources')
param environmentName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('A unique token for resource naming')
param resourceToken string

@description('Id of the user or app to assign application roles')
param principalId string

@description('Tags to be applied to all resources')
param tags object = {}

// Load resource abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Create storage account
module storage 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'storage'
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: union(tags, {
      'azd-service-name': 'storage'
    })
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    
    // Blob containers for face blur processing
    blobServices: {
      containers: [
        {
          name: 'source-images'
          publicAccess: 'None'
        }
        {
          name: 'processed-images'
          publicAccess: 'None'
        }
        {
          name: 'deployment'
          publicAccess: 'None'
        }
      ]
    }
    
    // Configure managed identity access
    managedIdentities: {
      systemAssigned: false
    }
  }
}

// Create Service Bus namespace and queue
module serviceBus 'br/public:avm/res/service-bus/namespace:0.8.0' = {
  name: 'serviceBus'
  params: {
    name: '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    tags: union(tags, {
      'azd-service-name': 'servicebus'
    })
    skuObject: {
      name: 'Standard'
    }
    
    // Create the image processing queue
    queues: [
      {
        name: 'image-processing-queue'
        maxDeliveryCount: 5
        defaultMessageTimeToLive: 'P14D'
        lockDuration: 'PT5M'
        deadLetteringOnMessageExpiration: true
        enablePartitioning: false
      }
    ]
    
    // Disable local auth to enforce managed identity
    disableLocalAuth: true
  }
}

// Create Computer Vision service
module computerVision 'br/public:avm/res/cognitive-services/account:0.7.0' = {
  name: 'computerVision'
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: union(tags, {
      'azd-service-name': 'computervision'
    })
    kind: 'ComputerVision'
    sku: 'F0'  // Free tier for development
    customSubDomainName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    disableLocalAuth: false  // Allow key-based auth for simplicity
    publicNetworkAccess: 'Enabled'
    
    managedIdentities: {
      systemAssigned: false
    }
  }
}

// Create the Function App with FlexConsumption plan
module functionApp './faceblur.bicep' = {
  name: 'faceblur'
  params: {
    environmentName: environmentName
    location: location
    resourceToken: resourceToken
    principalId: principalId
    tags: tags
    
    // Pass service dependencies
    storageAccountName: storage.outputs.name
    serviceBusNamespaceName: serviceBus.outputs.name
    computerVisionAccountName: computerVision.outputs.name
    computerVisionEndpoint: computerVision.outputs.endpoint
  }
}

// Create RBAC role assignments
module rbac './rbac.bicep' = {
  name: 'rbac'
  params: {
    functionAppPrincipalId: functionApp.outputs.identityPrincipalId
    storageAccountName: storage.outputs.name
    serviceBusNamespaceName: serviceBus.outputs.name
    computerVisionAccountName: computerVision.outputs.name
  }
}

// Outputs
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = functionApp.outputs.identityPrincipalId
output SERVICE_WEB_NAME string = functionApp.outputs.name
output SERVICE_WEB_URI string = functionApp.outputs.uri

output AZURE_STORAGE_ACCOUNT_ID string = storage.outputs.resourceId
output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.name

output AZURE_SERVICE_BUS_NAMESPACE_NAME string = serviceBus.outputs.name
output AZURE_SERVICE_BUS_QUEUE_NAME string = 'image-processing-queue'

output AZURE_COMPUTER_VISION_ACCOUNT_NAME string = computerVision.outputs.name
output AZURE_COMPUTER_VISION_ENDPOINT string = computerVision.outputs.endpoint

output SOURCE_CONTAINER_NAME string = 'source-images'
output DESTINATION_CONTAINER_NAME string = 'processed-images'
