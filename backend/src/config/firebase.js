const admin = require('firebase-admin');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config();

let serviceAccount;

try {
  // Load service account correctly as a JS object
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    serviceAccount = require(path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS));
  } else {
    serviceAccount = require('../../service-account-key.json');
  }
} catch (err) {
  console.error("Firebase init error: Failed to load service-account-key.json", err.message);
}

try {
  // Initialize safely (NO duplicate initialization)
  if (!admin.apps.length) {
    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      console.log("🔥 Firebase Admin initialized correctly");
    } else {
      console.error("Firebase init error: serviceAccount is undefined. Firebase was NOT initialized.");
    }
  }
} catch (err) {
  console.error("Firebase init error:", err);
}

let db = null;
let auth = null;

try {
  if (admin.apps.length) {
    db = admin.firestore();
    auth = admin.auth();
  }
} catch (err) {
  console.error("Firebase services init error:", err);
}

module.exports = { admin, db, auth };
