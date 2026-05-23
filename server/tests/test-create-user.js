// test-create-user.js
const { auth } = require('../src/config/firebase.config');

async function createTestUser() {
  try {
    const user = await auth.createUser({
      email: 'testcaregiver@example.com',
      password: 'TestPass123!',
      displayName: 'Test Caregiver',
    });

    console.log('✅ Test user created:');
    console.log('UID:', user.uid);
    console.log('Email:', user.email);
    console.log('\nNow get a token for this user...');
    
    // Generate a custom token
    const customToken = await auth.createCustomToken(user.uid);
    console.log('\nCustom Token:', customToken);
    console.log('\n⚠️ Use this token in Firebase Auth to get ID token');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

createTestUser();