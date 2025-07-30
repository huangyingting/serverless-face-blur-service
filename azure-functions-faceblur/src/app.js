/*! Copyright Microsoft. MIT License.
 *  Migrated from AWS Lambda to Azure Functions
 */

'use strict';

const { app } = require('@azure/functions');
const { detectFaces } = require('./detectFaces');
const { blurFaces } = require('./blurFaces');

/**
 * Azure Functions v4 Face Blur Function
 * Triggered by Service Bus Queue messages containing blob storage events
 * Processes images to detect and blur faces using Azure Computer Vision and GraphicsMagick
 */
app.serviceBusQueueTrigger('faceBlurFunction', {
    connection: 'ServiceBusConnection',
    queueName: 'image-processing-queue',
    handler: async (message, context) => {
        try {
            context.log('Face blur function triggered', { 
                messageId: context.triggerMetadata.messageId,
                enqueuedTimeUtc: context.triggerMetadata.enqueuedTimeUtc 
            });

            // Parse the Event Grid message from Service Bus
            let eventData;
            try {
                eventData = typeof message === 'string' ? JSON.parse(message) : message;
                context.log('Parsed event data:', JSON.stringify(eventData, null, 2));
            } catch (parseError) {
                context.log.error('Failed to parse message:', parseError);
                throw new Error('Invalid message format');
            }

            // Handle Event Grid event structure
            if (eventData.eventType && eventData.eventType === 'Microsoft.Storage.BlobCreated') {
                const blobUrl = eventData.data.url;
                const urlParts = new URL(blobUrl);
                const containerName = urlParts.pathname.split('/')[1];
                const blobName = urlParts.pathname.split('/').slice(2).join('/');
                
                context.log(`Processing blob: ${blobName} from container: ${containerName}`);

                // Only process JPG images
                if (!blobName.toLowerCase().endsWith('.jpg') && !blobName.toLowerCase().endsWith('.jpeg')) {
                    context.log('Skipping non-JPG file:', blobName);
                    return;
                }

                // Detect faces in the image
                const faceDetails = await detectFaces(containerName, blobName, context);
                context.log(`Detected ${faceDetails.length} faces in image`);

                if (faceDetails.length === 0) {
                    context.log('No faces detected, skipping blur operation');
                    return;
                }

                // Blur faces in the image
                const processedBuffer = await blurFaces(containerName, blobName, faceDetails, context);

                // The blurFaces function handles saving to destination container
                context.log('Successfully processed and saved blurred image');

            } else {
                context.log.warn('Unhandled event type:', eventData.eventType);
            }

        } catch (error) {
            context.log.error('Error processing face blur:', error);
            // Re-throw to trigger retry logic if configured
            throw error;
        }
    }
});

/**
 * Alternative HTTP trigger for testing purposes
 * Can be used to manually trigger face blur processing
 */
app.http('faceBlurTest', {
    methods: ['POST'],
    authLevel: 'function',
    handler: async (request, context) => {
        try {
            const body = await request.json();
            const { containerName, blobName } = body;

            if (!containerName || !blobName) {
                return {
                    status: 400,
                    jsonBody: { 
                        error: 'containerName and blobName are required' 
                    }
                };
            }

            context.log(`Test trigger: Processing ${blobName} from ${containerName}`);

            // Detect faces
            const faceDetails = await detectFaces(containerName, blobName, context);
            
            if (faceDetails.length === 0) {
                return { 
                    jsonBody: { 
                        message: 'No faces detected',
                        facesFound: 0 
                    }
                };
            }

            // Blur faces
            await blurFaces(containerName, blobName, faceDetails, context);

            return { 
                jsonBody: { 
                    message: 'Successfully processed image',
                    facesFound: faceDetails.length 
                }
            };

        } catch (error) {
            context.log.error('Test trigger error:', error);
            return {
                status: 500,
                jsonBody: { 
                    error: 'Internal server error',
                    details: error.message 
                }
            };
        }
    }
});
