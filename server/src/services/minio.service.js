const Minio  = require('minio');
const logger = require('../utils/logger');

// Internal client — used for all MinIO operations inside Docker
const minioClient = new Minio.Client({
  endPoint:  process.env.MINIO_ENDPOINT || 'minio',
  port:      parseInt(process.env.MINIO_PORT || '9000'),
  useSSL:    process.env.MINIO_USE_SSL === 'true',
  accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
  secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
});

// Public base URL — used to build direct (non-presigned) URLs for the mobile app.
// The bucket is set to public-read so no signing is needed and URLs never expire.
const _publicHost = process.env.MINIO_PUBLIC_HOST || 'localhost';
const _publicPort = parseInt(process.env.MINIO_PUBLIC_PORT || '9000');
const _publicBase = `http://${_publicHost}:${_publicPort}`;

const BUCKET_NAME = 'sanad';

// Public-read bucket policy — allows anyone to GET objects without signing.
// This means snapshot/voice URLs never expire and work from any device on the LAN.
const PUBLIC_READ_POLICY = JSON.stringify({
  Version: '2012-10-17',
  Statement: [
    {
      Effect:    'Allow',
      Principal: '*',
      Action:    ['s3:GetObject'],
      Resource:  [`arn:aws:s3:::${BUCKET_NAME}/*`],
    },
  ],
});

class MinioService {
  async initialize() {
    const exists = await minioClient.bucketExists(BUCKET_NAME);
    if (!exists) {
      await minioClient.makeBucket(BUCKET_NAME);
      logger.info(`✓ MinIO bucket '${BUCKET_NAME}' created`);
    } else {
      logger.info(`✓ MinIO bucket '${BUCKET_NAME}' ready`);
    }

    // Apply public-read policy so URLs never expire
    try {
      await minioClient.setBucketPolicy(BUCKET_NAME, PUBLIC_READ_POLICY);
      logger.info(`✓ MinIO bucket '${BUCKET_NAME}' set to public-read`);
    } catch (err) {
      logger.warn(`⚠ Could not set bucket policy: ${err.message}`);
    }
  }

  // Build a permanent public URL for an object (no presigning, no expiry)
  _publicUrl(fileName) {
    return `${_publicBase}/${BUCKET_NAME}/${fileName}`;
  }

  async uploadSnapshot(elderlyId, imageBuffer, eventType) {
    const timestamp = Date.now();
    const fileName  = `snapshots/${elderlyId}/${eventType}_${timestamp}.jpg`;

    await minioClient.putObject(
      BUCKET_NAME, fileName, imageBuffer, imageBuffer.length,
      { 'Content-Type': 'image/jpeg' }
    );

    const url = this._publicUrl(fileName);
    logger.info(`✓ Snapshot saved: ${fileName}`);
    return url;
  }

  async uploadVideoClip(elderlyId, videoBuffer, eventType) {
    const timestamp = Date.now();
    const fileName  = `clips/${elderlyId}/${eventType}_${timestamp}.mp4`;

    await minioClient.putObject(
      BUCKET_NAME, fileName, videoBuffer, videoBuffer.length,
      { 'Content-Type': 'video/mp4' }
    );

    const url = this._publicUrl(fileName);
    logger.info(`✓ Video clip saved: ${fileName}`);
    return url;
  }

  async uploadVoiceMessage(caregiverId, audioBuffer, mimeType) {
    const timestamp = Date.now();
    const ext = mimeType.includes('mp4') || mimeType.includes('m4a') ? 'm4a'
              : mimeType.includes('mpeg') || mimeType.includes('mp3') ? 'mp3'
              : 'aac';
    const fileName = `voice/${caregiverId}/${timestamp}.${ext}`;

    await minioClient.putObject(
      BUCKET_NAME, fileName, audioBuffer, audioBuffer.length,
      { 'Content-Type': mimeType }
    );

    const url = this._publicUrl(fileName);
    logger.info(`✓ Voice message saved: ${fileName}`);
    return url;
  }

  async deleteFile(fileUrl) {
    try {
      const parsed = new URL(fileUrl);
      // Handle both old presigned URLs (query string) and new plain URLs
      let pathPart = decodeURIComponent(parsed.pathname);
      // Strip leading /<bucket>/ prefix
      pathPart = pathPart.replace(new RegExp(`^\\/${BUCKET_NAME}\\/`), '');
      // Strip any query-string remnants (shouldn't be in pathname, but just in case)
      const fileName = pathPart.split('?')[0];
      await minioClient.removeObject(BUCKET_NAME, fileName);
      logger.info(`✓ File deleted: ${fileName}`);
    } catch (err) {
      logger.warn(`deleteFile skipped: ${err.message}`);
    }
  }
}

module.exports = new MinioService();
