const dotenv = require('dotenv');
const path = require('path');
dotenv.config({ path: path.resolve(__dirname, '..', '.env') });
const { auth } = require('../src/config/firebase.config');
async function testFirebase() {
try {
console.log('Testing Firebase connection...');
// Try to list users (will fail if no users, but proves connection works)
const listUsersResult = await auth.listUsers(1);
console.log('✓ Firebase connected successfully!');
console.log('Users in database:', listUsersResult.users.length);
process.exit(0);
} catch (error) {
console.error('✗ Firebase connection failed:', error.message);
process.exit(1);
}
}
testFirebase();