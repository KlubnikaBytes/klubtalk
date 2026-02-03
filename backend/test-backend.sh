#!/bin/bash

# VPS Backend Connectivity Test Script
# Run this on your VPS: bash test-backend.sh

echo "🧪 Testing Backend Connectivity..."
echo ""

# 1. Check if backend is running
echo "1️⃣ Checking if backend is running on port 6000..."
if nc -z localhost 6000; then
    echo "   ✅ Backend is listening on port 6000"
else
    echo "   ❌ Backend is NOT running on port 6000"
    echo "   Run: pm2 start index.js --name whatsapp-backend"
    exit 1
fi

# 2. Test health endpoint
echo ""
echo "2️⃣ Testing health endpoint..."
curl -s http://localhost:6000/health | jq '.' || echo "   ❌ Health check failed"

# 3. Test OTP endpoint (local)
echo ""
echo "3️⃣ Testing OTP endpoint (localhost)..."
curl -X POST http://localhost:6000/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"1234567890"}' | jq '.'

# 4. Test OTP endpoint (external IP)
echo ""
echo "4️⃣ Testing OTP endpoint (external IP)..."
EXTERNAL_IP=$(hostname -I | awk '{print $1}')
curl -X POST http://${EXTERNAL_IP}:6000/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"1234567890"}' | jq '.'

# 5. Check firewall
echo ""
echo "5️⃣ Checking firewall rules..."
sudo ufw status | grep 6000 || echo "   ⚠️  Port 6000 not in firewall rules"

# 6. Check PM2 logs
echo ""
echo "6️⃣ Recent PM2 logs (last 20 lines)..."
pm2 logs whatsapp-backend --lines 20 --nostream

echo ""
echo "✅ Test complete!"
