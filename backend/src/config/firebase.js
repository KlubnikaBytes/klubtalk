const admin = require("firebase-admin");

let firebaseApp;

if (!admin.apps.length) {
  const serviceAccount = require("../../service-account-key.json");

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log("🔥 Firebase Admin initialized ONCE");
} else {
  firebaseApp = admin.app();
}

module.exports = { admin, firebaseApp };
