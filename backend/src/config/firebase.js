const admin = require("firebase-admin");

if (!admin.apps.length) {
  const serviceAccount = require("../../service-account-key.json");

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log("🔥 Firebase Admin initialized correctly");
}

module.exports = admin;
