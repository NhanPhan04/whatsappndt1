const http = require('http');

// Test health endpoint
const testHealth = () => {
  const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/health',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    }
  };

  const req = http.request(options, (res) => {
    console.log('✅ Health Check Status:', res.statusCode);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('📊 Health Response:', JSON.parse(data));
      
      // Test OTP endpoint
      testOTP();
    });
  });

  req.on('error', (error) => {
    console.error('❌ Health Check Error:', error);
  });

  req.end();
};

// Test OTP endpoint
const testOTP = () => {
  const postData = JSON.stringify({
    email: 'test@example.com'
  });

  const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/test-otp',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  const req = http.request(options, (res) => {
    console.log('✅ Test OTP Status:', res.statusCode);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('🧪 Test OTP Response:', JSON.parse(data));
    });
  });

  req.on('error', (error) => {
    console.error('❌ Test OTP Error:', error);
  });

  req.write(postData);
  req.end();
};

console.log('🚀 Testing WhatsApp NDT Backend...');
testHealth();
