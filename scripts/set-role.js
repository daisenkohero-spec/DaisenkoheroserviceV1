// Give a login account a role (admin tool).
//
// Usage:
//   node set-role.js <email> admin                     # existing account
//   node set-role.js <email> admin --create <password> # create the account too
//   node set-role.js <phone> technician                # 0811112222 → technician login
//   node set-role.js <email> none                      # remove the role
//
// The role is stored as a Firebase Auth custom claim (`role`). Only the Admin
// SDK can set it, so a self-created account can never make itself an admin.
// Security rules read it as request.auth.token.role.
//
// The user must sign out and back in (or wait up to an hour for their token to
// refresh) before a new role takes effect.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();

const ROLES = ["admin", "technician", "none"];

function toEmail(id) {
  const v = String(id).trim();
  return v.includes("@") ? v : `${v}@daisenkohero.local`;
}

async function main() {
  const [id, role, flag, password] = process.argv.slice(2);
  if (!id || !ROLES.includes(role)) {
    console.error("Usage: node set-role.js <email|phone> <admin|technician|none> [--create <password>]");
    process.exit(1);
  }
  const email = toEmail(id);

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    if (flag !== "--create") {
      console.error(`No login ${email}. Add --create <password> to create it.`);
      process.exit(1);
    }
    if (!password || password.length < 6) {
      console.error("Password must be at least 6 characters (Firebase minimum).");
      process.exit(1);
    }
    user = await auth.createUser({ email, password });
    console.log(`✓ Created login ${email}`);
  }

  const claims = { ...(user.customClaims || {}) };
  if (role === "none") delete claims.role;
  else claims.role = role;
  await auth.setCustomUserClaims(user.uid, claims);

  console.log(`✓ ${email} (uid ${user.uid}) role: ${role}`);
  console.log("  Takes effect after the user signs out and back in.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Failed to set role:", e.message);
  process.exit(1);
});
