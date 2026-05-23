require('dotenv').config();
const pool = require('../src/config/database.config');

async function testSelect() {
  try {
    const res = await pool.query('SELECT NOW()');
    console.log('✅ DB connected:', res.rows[0]);
  } catch (err) {
    console.error('❌ DB error:', err.message);
  } finally {
    pool.end();
  }
}

testSelect();
