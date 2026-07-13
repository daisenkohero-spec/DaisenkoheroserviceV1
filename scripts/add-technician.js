// Onboard a technician in one command (interim admin tool).
//
// Usage:
//   node add-technician.js "<name>" <phone> <password>
//
// Example:
//   node add-technician.js "ช่างสมชาย" 0811112222 changeme123
//
// Creates the Firebase Auth login (email = <phone>@daisenkohero.local) AND the
// matching `technicians` Firestore doc, linked by authUid, so the technician can
// log in immediately. Password must be at least 6 characters (Firebase minimum).

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();

function emailForPhone(phone) {
  return `${String(phone).trim()}@daisenkohero.local`;
}

async function main() {
  const [name, phone, password] = process.argv.slice(2);

  if (!name || !phone || !password) {
    console.error('Usage: node add-technician.js "<name>" <phone> <password>');
    process.exit(1);
  }
  if (password.length < 6) {
    console.error("Password must be at least 6 characters (Firebase minimum).");
    process.exit(1);
  }

  const email = emailForPhone(phone);

  // Refuse to duplicate an existing technician (same phone).
  const existing = await db
    .collection("technicians")
    .where("phone", "==", String(phone).trim())
    .limit(1)
    .get();
  if (!existing.empty) {
    console.error(`A technician with phone ${phone} already exists (doc ${existing.docs[0].id}).`);
    process.exit(1);
  }

  // 1) Create the Auth login.
  let userRecord;
  try {
    userRecord = await auth.createUser({ email, password, displayName: name });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      console.error(`Login ${email} already exists in Auth. Pick a different phone or remove the old user.`);
      process.exit(1);
    }
    throw e;
  }

  // 2) Create the technician profile, pre-linked to the Auth uid.
  const ref = await db.collection("technicians").add({
    name,
    phone: String(phone).trim(),
    authUid: userRecord.uid,
    status: "offline",
    createdAt: admin.firestore.Timestamp.now(),
  });

  console.log(`✓ Technician onboarded: ${name}`);
  console.log(`  Login phone: ${phone}`);
  console.log(`  Password:    ${password}`);
  console.log(`  Doc id:      ${ref.id}`);
  console.log(`  Give the technician their phone + password to log in.`);
  process.exit(0);
}

main().catch((e) => {
  console.error("Failed to onboard technician:", e.message);
  process.exit(1);
});
