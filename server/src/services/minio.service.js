const Minio  = require('minio');
const logger = require('../utils/logger');

// Internal client — used for putObject (fast, inside Docker network)
const minioClient = new Minio.Client({
  endPoint:  process.env.MINIO_ENDPOINT || 'localhost',
  port:      parseInt(process.env.MINIO_PORT || '9000'),
  useSSL:    process.env.MINIO_USE_SSL === 'true',
  accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
  secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
});

// Public host config — used to rewrite presigned URLs so Flutter can reach them.
// We sign with the internal client (minio:9000) to avoid ECONNREFUSED when
// 192.168.x.x is unreachable from inside Docker, then replace the host in
// the generated URL so the mobile app receives the correct public address.
const _publicHost = process.env.MINIO_PUBLIC_HOST || 'localhost';
const _publicPort = parseInt(process.env.MINIO_PUBLIC_PORT || '9000');

const BUCKET_NAME = 'sanad';
const SEVEN_DAYS  = 7 * 24 * 60 * 60;

class MinioService {
  async initialize() {
    const exists = await minioClient.bucketExists(BUCKET_NAME);
    if (!exists) {
      await minioClient.makeBucket(BUCKET_NAME);
      logger.info(`✓ MinIO bucket '${BUCKET_NAME}' created`);
    } else {
      logger.info(`✓ MinIO bucket '${BUCKET_NAME}' ready`);
    }
  }

  async uploadSnapshot(elderlyId, imageBuffer, eventType) {
    const timestamp = Date.now();
    const fileName  = `snapshots/${elderlyId}/${eventType}_${timestamp}.jpg`;

    await minioClient.putObject(
      BUCKET_NAME, fileName, imageBuffer, imageBuffer.length,
      { 'Content-Type': 'image/jpeg' }
    );

    // Sign with internal client (minio:9000), then rewrite host for mobile access
    const rawUrl = await minioClient.presignedGetObject(BUCKET_NAME, fileName, SEVEN_DAYS);
    const url = rawUrl.replace(`http://minio:9000`, `http://${_publicHost}:${_publicPort}`);

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

    const rawUrl = await minioClient.presignedGetObject(BUCKET_NAME, fileName, SEVEN_DAYS);
    const url = rawUrl.replace(`http://minio:9000`, `http://${_publicHost}:${_publicPort}`);

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

    const rawUrl = await minioClient.presignedGetObject(BUCKET_NAME, fileName, SEVEN_DAYS);
    const url = rawUrl.replace(`http://minio:9000`, `http://${_publicHost}:${_publicPort}`);

    logger.info(`✓ Voice message saved: ${fileName}`);
    return url;
  }

  async deleteFile(fileUrl) {
    try {
      const parsed   = new URL(fileUrl);
      const fileName = decodeURIComponent(parsed.pathname.replace(`/${BUCKET_NAME}/`, '').split('?')[0]);
      await minioClient.removeObject(BUCKET_NAME, fileName);
      logger.info(`✓ File deleted: ${fileName}`);
    } catch (err) {
      logger.warn(`deleteFile skipped: ${err.message}`);
    }
  }
}

module.exports = new MinioService();
