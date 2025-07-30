/*! Copyright Microsoft. MIT License.
 *  Migrated from AWS S3 to Azure Blob Storage
 */

'use strict';

const { BlobServiceClient } = require('@azure/storage-blob');
const { DefaultAzureCredential } = require('@azure/identity');
const sharp = require('sharp');

// Initialize Blob Service Client with Managed Identity
let blobServiceClient = null;

function getBlobServiceClient() {
    if (!blobServiceClient) {
        const storageAccountName = process.env.STORAGE_ACCOUNT_NAME;
        if (!storageAccountName) {
            throw new Error('STORAGE_ACCOUNT_NAME environment variable is required');
        }

        const accountUrl = `https://${storageAccountName}.blob.core.windows.net`;
        
        // Use Managed Identity for authentication
        const credential = new DefaultAzureCredential();
        blobServiceClient = new BlobServiceClient(accountUrl, credential);
    }
    return blobServiceClient;
}

/**
 * Download, blur faces, and upload processed image
 * @param {string} sourceContainer - Source container name
 * @param {string} blobName - Blob name (file path)
 * @param {Array} faceDetails - Array of face details with bounding boxes
 * @param {object} context - Azure Functions context for logging
 * @returns {Promise<Buffer>} Processed image buffer
 */
const blurFaces = async (sourceContainer, blobName, faceDetails, context) => {
    try {
        context.log(`Blurring faces in: ${sourceContainer}/${blobName}`);

        const blobClient = getBlobServiceClient();
        const sourceContainerClient = blobClient.getContainerClient(sourceContainer);
        const sourceBlobClient = sourceContainerClient.getBlobClient(blobName);

        // Download the original image
        context.log('Downloading original image...');
        const downloadResponse = await sourceBlobClient.download();
        const imageBuffer = await streamToBuffer(downloadResponse.readableStreamBody);
        
        context.log(`Downloaded image size: ${imageBuffer.length} bytes`);

        // Use Sharp instead of GraphicsMagick for better Node.js integration
        let image = sharp(imageBuffer);
        
        // Get image metadata to calculate absolute coordinates
        const metadata = await image.metadata();
        const { width: imageWidth, height: imageHeight } = metadata;
        
        context.log(`Image dimensions: ${imageWidth}x${imageHeight}`);

        // Apply blur to each detected face
        for (let i = 0; i < faceDetails.length; i++) {
            const face = faceDetails[i];
            const box = face.BoundingBox;
            
            let left, top, width, height;
            
            if (box.IsPixelCoordinates) {
                // Computer Vision returns pixel coordinates
                left = Math.round(box.Left);
                top = Math.round(box.Top);
                width = Math.round(box.Width);
                height = Math.round(box.Height);
            } else {
                // Convert relative coordinates (0-1) to pixels (for backward compatibility)
                width = Math.round(box.Width * imageWidth);
                height = Math.round(box.Height * imageHeight);
                left = Math.round(box.Left * imageWidth);
                top = Math.round(box.Top * imageHeight);
            }

            // Ensure coordinates are within image bounds
            left = Math.max(0, Math.min(left, imageWidth - 1));
            top = Math.max(0, Math.min(top, imageHeight - 1));
            width = Math.min(width, imageWidth - left);
            height = Math.min(height, imageHeight - top);

            context.log(`Blurring face ${i + 1}: region ${left},${top} ${width}x${height}`);

            // Extract the face region
            const faceBuffer = await sharp(imageBuffer)
                .extract({ left, top, width, height })
                .blur(20) // Blur intensity (equivalent to GraphicsMagick's blur 0,70)
                .toBuffer();

            // Composite the blurred face back onto the original image
            image = image.composite([{
                input: faceBuffer,
                top: top,
                left: left
            }]);
        }

        // Generate the final processed image
        const processedBuffer = await image.jpeg({ quality: 90 }).toBuffer();
        
        context.log(`Processed image size: ${processedBuffer.length} bytes`);

        // Upload to destination container
        const destinationContainer = process.env.DESTINATION_CONTAINER_NAME || 'processed-images';
        const destinationContainerClient = blobClient.getContainerClient(destinationContainer);
        
        // Ensure destination container exists
        await destinationContainerClient.createIfNotExists({
            access: 'blob'
        });

        const destinationBlobClient = destinationContainerClient.getBlobClient(blobName);
        
        context.log(`Uploading processed image to: ${destinationContainer}/${blobName}`);
        
        await destinationBlobClient.uploadData(processedBuffer, {
            blobHTTPHeaders: {
                blobContentType: 'image/jpeg'
            },
            metadata: {
                processed: 'true',
                facesBlurred: faceDetails.length.toString(),
                processedAt: new Date().toISOString()
            }
        });

        context.log(`Successfully uploaded processed image with ${faceDetails.length} blurred faces`);
        
        return processedBuffer;

    } catch (error) {
        context.log.error('Face blurring error:', error);
        
        // Handle specific Azure Storage errors
        if (error.code === 'BlobNotFound') {
            throw new Error(`Source blob not found: ${sourceContainer}/${blobName}`);
        } else if (error.code === 'ContainerNotFound') {
            throw new Error(`Source container not found: ${sourceContainer}`);
        } else if (error.code === 'AuthorizationFailure') {
            throw new Error('Storage access denied. Check managed identity permissions.');
        }
        
        throw error;
    }
};

/**
 * Helper function to convert stream to buffer
 * @param {ReadableStream} readableStream 
 * @returns {Promise<Buffer>}
 */
async function streamToBuffer(readableStream) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        readableStream.on('data', (data) => {
            chunks.push(data instanceof Buffer ? data : Buffer.from(data));
        });
        readableStream.on('end', () => {
            resolve(Buffer.concat(chunks));
        });
        readableStream.on('error', reject);
    });
}

module.exports = { blurFaces };
