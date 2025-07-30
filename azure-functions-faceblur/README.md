# Azure Functions Face Blur Service

This Azure Functions application automatically detects and blurs faces in images uploaded to Azure Blob Storage. It's migrated from the original AWS Lambda implementation to use Azure services.

## Architecture

The application uses the following Azure services:
- **Azure Functions v4** (JavaScript) - Serverless compute
- **Azure Blob Storage** - Image storage (source and processed)
- **Azure Computer Vision** - Face detection service
- **Azure Service Bus** - Message queue for event processing
- **Azure Application Insights** - Monitoring and logging

## Features

- **Automatic Processing**: Triggered by blob storage events via Service Bus
- **Face Detection**: Uses Azure Computer Vision API to detect faces
- **Image Processing**: Uses Sharp.js for high-performance image blurring
- **Managed Identity**: Secure authentication without storing credentials
- **Monitoring**: Comprehensive logging and error handling
- **Testing**: HTTP endpoint for manual testing

## Project Structure

```
azure-functions-faceblur/
├── src/
│   ├── app.js              # Main Azure Functions v4 application
│   ├── detectFaces.js      # Computer Vision face detection
│   └── blurFaces.js        # Image processing and blob storage
├── host.json               # Functions host configuration
├── local.settings.json     # Local development settings (template)
├── package.json            # Dependencies and scripts
└── README.md              # This file
```

## Functions

### 1. faceBlurFunction (Service Bus Trigger)
- **Trigger**: Service Bus Queue message
- **Purpose**: Main processing function for automated face blurring
- **Input**: Event Grid message from blob storage events
- **Output**: Processed image saved to destination container

### 2. faceBlurTest (HTTP Trigger)
- **Trigger**: HTTP POST request
- **Purpose**: Manual testing and debugging
- **Input**: JSON with `containerName` and `blobName`
- **Output**: Processing result with face count

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ServiceBusConnection` | Service Bus connection string | `Endpoint=sb://...` |
| `COMPUTER_VISION_ENDPOINT` | Computer Vision service endpoint | `https://region.api.cognitive.microsoft.com/` |
| `STORAGE_ACCOUNT_NAME` | Storage account name | `mystorageaccount` |
| `SOURCE_CONTAINER_NAME` | Source images container | `source-images` |
| `DESTINATION_CONTAINER_NAME` | Processed images container | `processed-images` |

### Managed Identity Permissions

The function app requires the following permissions:
- **Storage Blob Data Contributor** on the storage account
- **Cognitive Services User** on the Computer Vision service
- **Azure Service Bus Data Receiver** on the Service Bus queue

## Local Development

1. Install dependencies:
   ```bash
   npm install
   ```

2. Install Azure Functions Core Tools:
   ```bash
   npm install -g @azure/functions-core-tools@4 --unsafe-perm true
   ```

3. Configure `local.settings.json` with your Azure resources

4. Start the function locally:
   ```bash
   npm start
   ```

## Deployment

The function can be deployed using:
- Azure CLI
- Azure Functions extension for VS Code
- GitHub Actions / Azure DevOps
- Infrastructure as Code (Bicep/ARM templates)

## Testing

### Manual Testing (HTTP Endpoint)

```bash
curl -X POST http://localhost:7071/api/faceBlurTest \
  -H "Content-Type: application/json" \
  -d '{"containerName": "source-images", "blobName": "test-image.jpg"}'
```

### Automated Testing

Upload a JPG image to the source container and verify:
1. Service Bus receives the event message
2. Function processes the image
3. Processed image appears in destination container
4. Application Insights logs the operation

## Migration Notes

This application was migrated from AWS Lambda with the following changes:

### Service Mappings
- **AWS Lambda** → **Azure Functions v4**
- **Amazon S3** → **Azure Blob Storage**
- **Amazon SQS** → **Azure Service Bus**
- **Amazon Rekognition** → **Azure Computer Vision**
- **GraphicsMagick** → **Sharp.js**

### Key Improvements
- **Better Performance**: Sharp.js is faster than GraphicsMagick for Node.js
- **Managed Identity**: No credential management required
- **Enhanced Logging**: Application Insights integration
- **Modern JavaScript**: Uses Azure Functions v4 programming model
- **Better Error Handling**: Comprehensive error handling and retry logic

## Monitoring

The application includes comprehensive monitoring:
- Function execution metrics
- Computer Vision API usage
- Blob storage operations
- Error tracking and alerting
- Performance monitoring

Access logs via Azure Portal → Application Insights → Logs.

## License

MIT License - Migrated from original AWS Lambda implementation.
