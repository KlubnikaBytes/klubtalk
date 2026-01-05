# WhatsApp Clone - Node.js Backend Setup

This backend implements the **Hybrid Architecture**:
-   **Firestore/Auth**: Managed via Firebase Admin SDK.
-   **Storage**: Managed via Local Disk (VPS) served via Express.

## 1. Prerequisites
-   Node.js & npm installed on your VPS/Machine.
-   A **service-account-key.json** file from your Firebase Console.
    -   Go to Project Settings > Service accounts > Generate new private key.
    -   Rename it to `service-account-key.json` and place it in the `backend/` root folder.

## 2. Configuration
1.  Navigate to `backend/`.
2.  Copy `.env.example` to `.env`.
3.  Update `.env`:
    ```ini
    GOOGLE_APPLICATION_CREDENTIALS=./service-account-key.json
    VPS_PUBLIC_URL=http://your-vps-ip:3000
    ```
    *Note: For local testing, leave URL as localhost.*

## 3. Installation
```bash
cd backend
npm install
```

## 4. Running
-   **Development**:
    ```bash
    npm run dev
    ```
-   **Production (VPS)**:
    ```bash
    npm start
    ```
    *Tip: Use PM2 to keep it running: `pm2 start index.js --name whatsapp-backend`*

## 5. Connecting Flutter App
Update your `lib/config/api_config.dart` in the Flutter app to point to this backend:

```dart
class ApiConfig {
  static const String baseUrl = 'http://your-vps-ip:3000'; 
  ...
}
```

Now, when you send a voice message, the Flutter app will:
1.  Get a Firebase Token.
2.  Send the file to `POST /upload/audio`.
3.  The Backend saves it to `backend/uploads/`.
4.  The Backend returns a URL like `http://.../uploads/filename.m4a`.
5.  Flutter saves this URL to Firestore.
