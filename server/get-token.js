// get-token.js
const { auth } = require('./src/config/firebase.config');

async function getToken(email) {
  try {
    const user = await auth.getUserByEmail(email);
    const customToken = await auth.createCustomToken(user.uid);
    
    console.log('User UID:', user.uid);
    console.log('Custom Token:', customToken);
    console.log('\n📝 To get ID token:');
    console.log('1. Use Firebase REST API:');
    console.log(`
curl -X POST 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=YOUR_WEB_API_KEY' \\
  -H 'Content-Type: application/json' \\
  -d '{"token":"${customToken}","returnSecureToken":true}'
    `);
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

const email = process.argv[2] || 'testcaregiver@example.com';
getToken(email);