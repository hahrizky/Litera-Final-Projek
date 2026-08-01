const admin = require("firebase-admin");
const serviceAccount = require("./litera2-c50c9-firebase-adminsdk-fbsvc-3d5f7ff195.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function makeAdmin() {
  const user = await admin.auth().getUserByEmail(
    "ekarizqiromadhon6@gmail.com"
  );

  await admin.auth().setCustomUserClaims(user.uid, {
    admin: true,
  });

  console.log("Admin berhasil dibuat");
}

makeAdmin();