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

@description('Storage account name for the Function App')
param storageAccountName string

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Computer Vision account name')
param computerVisionAccountName string

@description('Computer Vision endpoint')
param computerVisionEndpoint string

// Load resource abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Create managed identity for the Function App
module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'faceblur-identity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}faceblur-${resourceToken}'
    location: location
    tags: tags
  }
}

// Create FlexConsumption Function App
module functionApp 'br/public:avm/res/web/site:0.11.1' = {
  name: 'faceblur-function'
  params: {
    name: '${abbrs.webSitesFunctions}faceblur-${resourceToken}'
    location: location
    tags: union(tags, {
      'azd-service-name': 'faceblur'
    })
    
    kind: 'functionapp,linux'
    
    // Use FlexConsumption hosting plan
    serverFarmResourceId: ''  // FlexConsumption doesn't use traditional App Service Plan
    
    // Configure managed identity
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        managedIdentity.outputs.resourceId
      ]
    }
    
    // Site configuration
    siteConfig: {
      alwaysOn: false  // Not applicable for FlexConsumption
      linuxFxVersion: 'NODE|18'
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      httpsOnly: true
      
      cors: {
        allowedOrigins: ['*']
        supportCredentials: false
      }
      
      // Application settings
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        // Storage settings using managed identity
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.outputs.storageAccountKey1};EndpointSuffix=core.windows.net'
        }
        // Service Bus settings
        {
          name: 'SERVICE_BUS_NAMESPACE'
          value: '${serviceBusNamespaceName}.servicebus.windows.net'
        }
        {
          name: 'SERVICE_BUS_QUEUE_NAME'
          value: 'image-processing-queue'
        }
        // Computer Vision settings
        {
          name: 'COMPUTER_VISION_ENDPOINT'
          value: computerVisionEndpoint
        }
        // Storage container names
        {
          name: 'SOURCE_CONTAINER_NAME'
          value: 'source-images'
        }
        {
          name: 'DESTINATION_CONTAINER_NAME'
          value: 'processed-images'
        }
        // Storage account URL for blob operations
        {
          name: 'STORAGE_ACCOUNT_URL'
          value: 'https://${storageAccountName}.blob.core.windows.net'
        }
      ]
    }
    
    // FlexConsumption-specific configuration
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: 'https://${storageAccountName}.blob.core.windows.net/deployment'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      runtime: {
        name: 'node'
        version: '18'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
    }
    
    // Enable public network access
    publicNetworkAccess: 'Enabled'
    
    // Disable client affinity for better performance
    clientAffinityEnabled: false
    
    // Configure HTTPS only
    httpsOnly: true
  }
}

// Get reference to storage account for connection string
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Add diagnostic settings for Function App logs
resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'functionapp-diagnostics'
  scope: resourceId('Microsoft.Web/sites', functionApp.outputs.name)
  properties: {
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    workspaceId: null // Can be configured later with Log Analytics workspace
  }
}

// Outputs
output name string = functionApp.outputs.name
output uri string = 'https://${functionApp.outputs.defaultHostname}'
output identityPrincipalId string = functionApp.outputs.systemAssignedMIPrincipalId
