// Onboard an admin/dispatcher user in one command.
//
// Usage:
//   node add-admin.js "<name>" <email> <password>
//
// Admins log in with a real EMAIL (not a phone). Access comes from the
// `role: admin` custom claim (same as `set-role.js <email> admin`), which the
// security rules read. Password must be at least 6 characters.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();

async function main() {
  const [name, email, password] = process.argv.slice(2);
  if (!name || !email || !password) {
    console.error('Usage: node add-admin.js "<name>" <email> <password>');
    process.exit(1);
  }
  if (password.length < 6) {
    console.error("Password must be at least 6 characters (Firebase minimum).");
    process.exit(1);
  }

  let user;
  try {
    user = await auth.getUserByEmail(email);
    console.log(`• Login ${email} already exists — giving it admin access.`);
    await auth.updateUser(user.uid, { displayName: name });
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    user = await auth.createUser({ email, password, displayName: name });
    console.log(`✓ Created login ${email}`);
  }

  await auth.setCustomUserClaims(user.uid, { ...(user.customClaims || {}), role: "admin" });
  console.log(`✓ ${name} <${email}> is an admin (uid ${user.uid}).`);
  console.log("  Sign in with this email in the app to open the dispatcher.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Failed to add admin:", e.message);
  process.exit(1);
});
