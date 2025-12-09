require('dotenv').config();
const express = require('express');
const { execSync } = require('child_process');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const TARGET_REPO = process.env.TARGET_REPO || 'YOUR_ORG/YOUR_REPO';

app.post('/webhook', async (req, res) => {
  console.log('📥 Headers:', req.headers);
  console.log('📥 Body:', JSON.stringify(req.body, null, 2));
  
  const { repository, ref } = req.body;
  
  if (repository?.full_name === TARGET_REPO && ref?.startsWith('refs/heads/')) {
    console.log('🚀 Push detected, triggering Android build...');
    res.status(200).send('Android build triggered');
    
    try {
      execSync('./build-android.sh', { 
        cwd: __dirname, 
        stdio: 'inherit',
        env: { ...process.env }
      });
    } catch (error) {
      console.error('❌ Android build failed:', error.message);
    }
  } else {
    res.status(200).send('OK');
  }
});

app.listen(3003, () => console.log('Android webhook server running on port 3003'));