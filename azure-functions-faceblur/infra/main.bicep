targetScope = 'subscription'

@description('The environment name for the deployment (e.g., dev, staging, prod)')
@minLength(1)
@maxLength(64)
param environmentName string

@description('The primary location for all resources')
param location string = deployment().location

@description('Id of the user or app to assign application roles')
param principalId string = ''

// Generate a resource token for unique resource naming
var resourceToken = toLower(uniqueString(subscription().id, location, environmentName))

// Resource group for the deployment
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${environmentName}-rg'
  location: location
  tags: union(tags, {
    'azd-env-name': environmentName
  })
}

@description('Optional resource group name. If not provided, defaults to {env}-rg')
param resourceGroupName string = ''

@description('Tags to be applied to all resources')
param tags object = {}

// Deploy the main application infrastructure
module app 'app/main.bicep' = {
  name: 'app'
  scope: rg
  params: {
    environmentName: environmentName
    location: location
    resourceToken: resourceToken
    principalId: principalId
    tags: tags
  }
}

// Outputs for the deployment
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output RESOURCE_GROUP_ID string = rg.id

// Service outputs
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = app.outputs.SERVICE_WEB_IDENTITY_PRINCIPAL_ID
output SERVICE_WEB_NAME string = app.outputs.SERVICE_WEB_NAME
output SERVICE_WEB_URI string = app.outputs.SERVICE_WEB_URI

// Storage outputs
output AZURE_STORAGE_ACCOUNT_ID string = app.outputs.AZURE_STORAGE_ACCOUNT_ID
output AZURE_STORAGE_ACCOUNT_NAME string = app.outputs.AZURE_STORAGE_ACCOUNT_NAME

// Service Bus outputs
output AZURE_SERVICE_BUS_NAMESPACE_NAME string = app.outputs.AZURE_SERVICE_BUS_NAMESPACE_NAME
output AZURE_SERVICE_BUS_QUEUE_NAME string = app.outputs.AZURE_SERVICE_BUS_QUEUE_NAME

// Computer Vision outputs
output AZURE_COMPUTER_VISION_ACCOUNT_NAME string = app.outputs.AZURE_COMPUTER_VISION_ACCOUNT_NAME
output AZURE_COMPUTER_VISION_ENDPOINT string = app.outputs.AZURE_COMPUTER_VISION_ENDPOINT

// Environment variables
output SOURCE_CONTAINER_NAME string = app.outputs.SOURCE_CONTAINER_NAME
output DESTINATION_CONTAINER_NAME string = app.outputs.DESTINATION_CONTAINER_NAME
