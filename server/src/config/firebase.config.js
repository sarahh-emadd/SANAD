const admin = require('firebase-admin');
require('dotenv').config();

// Build service account from environment variables
const serviceAccount = {
type: 'service_account',
project_id: process.env.FIREBASE_PROJECT_ID,
private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
client_email: process.env.FIREBASE_CLIENT_EMAIL,
};
admin.initializeApp({
credential: admin.credential.cert(serviceAccount),
databaseURL: process.env.FIREBASE_DATABASE_URL,
});
const auth = admin.auth();
const messaging = admin.messaging();
const realtimeDb = admin.database();
console.log('✓ Firebase Admin SDK initialized');
module.exports = { admin, auth, messaging, realtimeDb };