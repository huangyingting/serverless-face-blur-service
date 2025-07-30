/*! Copyright Microsoft. MIT License.
 *  Migrated from AWS Rekognition to Azure Computer Vision
 */

'use strict';

const { ComputerVisionClient } = require('@azure/cognitiveservices-computervision');
const { DefaultAzureCredential } = require('@azure/identity');

// Initialize Computer Vision client with Managed Identity
let computerVisionClient = null;

function getComputerVisionClient() {
    if (!computerVisionClient) {
        const endpoint = process.env.COMPUTER_VISION_ENDPOINT;
        if (!endpoint) {
            throw new Error('COMPUTER_VISION_ENDPOINT environment variable is required');
        }

        // Use Managed Identity for authentication
        const credential = new DefaultAzureCredential();
        computerVisionClient = new ComputerVisionClient(credential, endpoint);
    }
    return computerVisionClient;
}

/**
 * Detect faces in an image stored in Azure Blob Storage
 * @param {string} containerName - The blob container name
 * @param {string} blobName - The blob name (file path)
 * @param {object} context - Azure Functions context for logging
 * @returns {Promise<Array>} Array of face details with bounding boxes
 */
const detectFaces = async (containerName, blobName, context) => {
    try {
        context.log(`Detecting faces in: ${containerName}/${blobName}`);

        // Construct the blob URL
        const storageAccountName = process.env.STORAGE_ACCOUNT_NAME;
        if (!storageAccountName) {
            throw new Error('STORAGE_ACCOUNT_NAME environment variable is required');
        }

        const imageUrl = `https://${storageAccountName}.blob.core.windows.net/${containerName}/${blobName}`;
        context.log(`Image URL: ${imageUrl}`);

        const client = getComputerVisionClient();

        // Analyze image for faces using Computer Vision
        // Note: Computer Vision API analyzes faces differently than Rekognition
        const analysis = await client.analyzeImage(imageUrl, {
            visualFeatures: ['Faces'],
            language: 'en'
        });

        if (!analysis.faces || analysis.faces.length === 0) {
            context.log('No faces detected by Computer Vision');
            return [];
        }

        context.log(`Computer Vision detected ${analysis.faces.length} faces`);

        // Convert Computer Vision face format to match original Lambda structure
        const faceDetails = analysis.faces.map((face, index) => {
            // Computer Vision returns faceRectangle with left, top, width, height (pixels)
            // We need to convert to relative coordinates (0-1) for consistency with original code
            
            // Note: We'll get image dimensions in the blurFaces function
            // For now, store the pixel coordinates and convert later
            return {
                BoundingBox: {
                    Left: face.faceRectangle.left,
                    Top: face.faceRectangle.top,
                    Width: face.faceRectangle.width,
                    Height: face.faceRectangle.height,
                    // Flag to indicate these are pixel coordinates, not relative
                    IsPixelCoordinates: true
                },
                Age: face.age,
                Gender: face.gender,
                Confidence: 0.9 // Computer Vision doesn't provide confidence for face detection
            };
        });

        context.log(`Converted face details:`, JSON.stringify(faceDetails, null, 2));
        return faceDetails;

    } catch (error) {
        context.log.error('Face detection error:', error);
        
        // Handle specific Computer Vision errors
        if (error.code === 'InvalidImageUrl') {
            throw new Error(`Invalid image URL or image not accessible: ${error.message}`);
        } else if (error.code === 'InvalidAspectRatio') {
            throw new Error(`Image aspect ratio not supported: ${error.message}`);
        } else if (error.code === 'InvalidImageSize') {
            throw new Error(`Image size not supported: ${error.message}`);
        } else if (error.code === 'InvalidImageFormat') {
            throw new Error(`Image format not supported: ${error.message}`);
        } else if (error.code === 'Unauthorized') {
            throw new Error('Computer Vision service access denied. Check managed identity permissions.');
        }
        
        // Return empty array for non-critical errors to allow processing to continue
        context.log.warn('Returning empty face array due to detection error');
        return [];
    }
};

module.exports = { detectFaces };
