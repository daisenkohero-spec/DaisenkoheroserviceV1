// One-time: move admins from the old `admins/{uid}` collection to the
// `role: admin` custom claim that the current security rules use.
//
// Usage:
//   node migrate-admins.js            # dry run
//   node migrate-admins.js --apply    # set the claims
//
// Until this runs, admins created with the July dispatcher build cannot open
// the dispatcher (the rules no longer read the `admins` collection).
// The `admins` docs are left in place; they are no longer used.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();
const apply = process.argv.includes("--apply");

async function main() {
  const snap = await db.collection("admins").get();
  let changed = 0;
  for (const doc of snap.docs) {
    const user = await auth.getUser(doc.id).catch(() => null);
    if (!user) {
      console.log(`skip ${doc.id}: no login with this uid`);
      continue;
    }
    const claims = user.customClaims || {};
    if (claims.role === "admin") {
      console.log(`ok   ${user.email}: already admin`);
      continue;
    }
    console.log(`${apply ? "SET " : "would set"} ${user.email}: role admin`);
    if (apply) {
      await auth.setCustomUserClaims(user.uid, { ...claims, role: "admin" });
      const name = doc.get("name");
      if (name && !user.displayName) await auth.updateUser(user.uid, { displayName: name });
    }
    changed++;
  }
  console.log(`\n${snap.size} admin docs · ${changed} ${apply ? "updated" : "to update (dry run)"}`);
  process.exit(0);
}

main().catch((e) => {
  console.error("Migration failed:", e.message);
  process.exit(1);
});
