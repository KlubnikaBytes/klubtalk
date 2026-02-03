#!/bin/bash

# VPS Deployment Script for WhatsApp Clone Backend
# Run this on your VPS: bash deploy.sh

echo "🚀 Starting deployment..."

# 1. Navigate to project directory
cd ~/new-messaging-app

# 2. Pull latest code
echo "📥 Pulling latest code..."
git pull origin main

# 3. Update folder structure
echo "📁 Setting up upload folders..."
cd uploads

# Rename folders if they don't match
[ -d "docs" ] && mv docs files
[ -d "audio" ] && mv audio voice

# Create folders if they don't exist
mkdir -p avatars images voice files

# Set permissions
chmod -R 755 .

cd ..

# 4. Install backend dependencies  
echo "📦 Installing backend dependencies..."
cd backend
npm install

# 5. Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating template..."
    cat > .env << 'EOF'
# MongoDB Connection
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/yourdb

# Server Configuration
PORT=6000
BASE_URL=http://YOUR_VPS_IP:6000

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
EOF
    echo "⚠️  Please edit backend/.env with your actual values!"
    exit 1
fi

# 6. Restart backend with PM2
echo "🔄 Restarting backend..."
pm2 delete whatsapp-backend 2>/dev/null || true
pm2 start index.js --name "whatsapp-backend"
pm2 save

# 7. Show status
echo "✅ Deployment complete!"
echo ""
echo "📊 Backend Status:"
pm2 status

echo ""
echo "📁 Upload Folders:"
ls -la ../uploads/

echo ""
echo "🌐 API URLs:"
echo "   - Health: http://$(hostname -I | awk '{print $1}'):6000/health"
echo "   - Uploads: http://$(hostname -I | awk '{print $1}'):6000/uploads/"
