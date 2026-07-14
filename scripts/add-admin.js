// Onboard an admin/dispatcher user in one command.
//
// Usage:
//   node add-admin.js "<name>" <email> <password>
//
// Example:
//   node add-admin.js "Tharat (Owner)" owner@daisenkohero.com pilot2026
//
// Admins log in with a real EMAIL (not a phone), and get a doc at admins/{uid}
// that grants dispatcher access. Password must be at least 6 characters.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();

async function main() {
  const [name, email, password] = process.argv.slice(2);

  if (!name || !email || !password) {
    console.error('Usage: node add-admin.js "<name>" <email> <password>');
    process.exit(1);
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    console.error(`"${email}" is not a valid email address.`);
    process.exit(1);
  }
  if (password.length < 6) {
    console.error("Password must be at least 6 characters (Firebase minimum).");
    process.exit(1);
  }

  // Reuse an existing Auth user with this email if present; otherwise create one.
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`(using existing Auth user ${email})`);
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      userRecord = await auth.createUser({ email, password, displayName: name });
    } else {
      throw e;
    }
  }

  // Grant admin by writing admins/{uid}. Doc id = the user's Auth uid so the
  // security rules can check membership with a simple exists() lookup.
  await db.collection("admins").doc(userRecord.uid).set({
    name,
    email,
    createdAt: admin.firestore.Timestamp.now(),
  });

  console.log(`✓ Admin ready: ${name}`);
  console.log(`  Login email: ${email}`);
  console.log(`  Password:    ${password}  (unchanged if the user already existed)`);
  console.log(`  Admin uid:   ${userRecord.uid}`);
  process.exit(0);
}

main().catch((e) => {
  console.error("Failed to add admin:", e.message);
  process.exit(1);
});
