# WhatsApp Clone Backend - VPS Deployment Guide

## ✅ What's Already Implemented

Your backend already has:
- ✅ Multer configured for file uploads
- ✅ `/upload/image` route for media uploads
- ✅ Static file serving at `/uploads/*`
- ✅ Proper MIME type detection
- ✅ MongoDB Atlas for text/call data
- ✅ VPS filesystem for media storage

## 📁 Folder Structure

```
uploads/
├── avatars/       → Profile pictures
├── images/        → Images AND Videos (combined)
├── voice/         → Audio messages
└── files/         → Documents (PDFs, etc)
```

## 🚀 Deployment Steps

### 1. Upload Code to VPS

```bash
# From local machine
cd c:\Users\Klubnika Bytes\Downloads\whatsapp-clone
git add .
git commit -m "Update media storage structure"
git push origin main
```

### 2. Run Deployment Script on VPS

```bash
# SSH into VPS
ssh root@srv1208756

# Copy and run deployment script
cd ~/new-messaging-app/backend
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Pull latest code
- Create/rename folders
- Install dependencies
- Restart backend with PM2

### 3. Verify Backend is Running

```bash
# Check PM2 status
pm2 status

# View logs
pm2 logs whatsapp-backend

# Test health endpoint
curl http://localhost:5000/health
```

### 4. Update Flutter App

Edit `lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'http://YOUR_VPS_IP:5000';
  // Replace YOUR_VPS_IP with actual IP
  
  // ... rest stays same
}
```

## 🔧 Environment Variables (.env)

Make sure `backend/.env` on VPS contains:

```env
# MongoDB Atlas (text messages & call logs)
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/yourdb

# Server Config
PORT=5000
BASE_URL=http://YOUR_VPS_IP:5000

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-service-account@firebase.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

## 📡 API Endpoints

### Upload Media
```http
POST /upload/image
Content-Type: multipart/form-data

Body:
- file: <binary file>
```

Response:
```json
{
  "message": "Media uploaded successfully",
  "url": "/uploads/images/1234567890-abc.jpg",
  "type": "image",
  "mime": "image/jpeg",
  "filename": "photo.jpg",
  "size": 123456
}
```

### Access Media
```
GET http://YOUR_VPS_IP:5000/uploads/images/filename.jpg
GET http://YOUR_VPS_IP:5000/uploads/files/document.pdf
GET http://YOUR_VPS_IP:5000/uploads/voice/audio.mp3
GET http://YOUR_VPS_IP:5000/uploads/avatars/profile.jpg
```

## 🎯 Data Storage Summary

| Data Type | Storage Location |
|-----------|------------------|
| Text messages | MongoDB Atlas |
| Call logs | MongoDB Atlas |
| User profiles | MongoDB Atlas |
| Images | VPS: `/uploads/images/` |
| Videos | VPS: `/uploads/images/` |
| Documents | VPS: `/uploads/files/` |
| Voice notes | VPS: `/uploads/voice/` |
| Avatars | VPS: `/uploads/avatars/` |

## 🔒 Security Notes

- Files are publicly accessible via HTTP
- Consider adding authentication for sensitive files
- Use HTTPS in production (setup Nginx with SSL)

## 📝 PM2 Commands

```bash
# View status
pm2 status

# View logs
pm2 logs whatsapp-backend

# Restart
pm2 restart whatsapp-backend

# Stop
pm2 stop whatsapp-backend

# Delete
pm2 delete whatsapp-backend
```
