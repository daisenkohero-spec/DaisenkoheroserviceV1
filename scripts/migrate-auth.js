// One-time migration for existing technicians (admin tool).
//
// Usage:
//   node migrate-auth.js            # dry run: shows what would change
//   node migrate-auth.js --apply    # writes the changes
//
// For every doc in `technicians`:
//   1. If it has no `authUid`, finds the Firebase Auth user whose email is
//      "<phone>@daisenkohero.local" and links it (sets `authUid`).
//      The app no longer links accounts on first login, so an unlinked
//      technician cannot log in until this runs.
//   2. Deletes the legacy plaintext `password` field.
//   3. Gives every linked login the `technician` role claim (unless it
//      already has a role, e.g. an admin who is also on the tools).
//
// Technicians with no matching Auth user are listed at the end: create their
// login with add-technician.js (or Console → Authentication → Add user) and
// run this script again.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();

const apply = process.argv.includes("--apply");

function emailForPhone(phone) {
  return `${String(phone).trim()}@daisenkohero.local`;
}

async function main() {
  const snap = await db.collection("technicians").get();
  const linkedUids = new Set(
    snap.docs.map((d) => d.get("authUid")).filter(Boolean),
  );
  const missing = [];
  let linked = 0;
  let stripped = 0;
  let roled = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const update = {};

    if (!data.authUid) {
      if (!data.phone) {
        missing.push(`${doc.id} (no phone)`);
      } else {
        try {
          const user = await auth.getUserByEmail(emailForPhone(data.phone));
          if (linkedUids.has(user.uid)) {
            missing.push(`${doc.id} (Auth user ${user.uid} already linked to another doc)`);
          } else {
            update.authUid = user.uid;
            linkedUids.add(user.uid);
            linked++;
          }
        } catch (e) {
          if (e.code !== "auth/user-not-found") throw e;
          missing.push(`${doc.id} (${data.name ?? "?"}, ${data.phone}): no Auth user`);
        }
      }
    }

    const uid = update.authUid || data.authUid;
    if (uid) {
      const user = await auth.getUser(uid).catch(() => null);
      if (user && !(user.customClaims && user.customClaims.role)) {
        console.log(`${apply ? "ROLE" : "would set role"} ${doc.id}: technician`);
        if (apply) await auth.setCustomUserClaims(uid, { ...(user.customClaims || {}), role: "technician" });
        roled++;
      }
    }

    if ("password" in data) {
      update.password = admin.firestore.FieldValue.delete();
      stripped++;
    }

    if (Object.keys(update).length > 0) {
      const shown = Object.keys(update).map((k) => (k === "password" ? "-password" : `${k}=${update[k]}`));
      console.log(`${apply ? "UPDATE" : "would update"} ${doc.id}: ${shown.join(", ")}`);
      if (apply) await doc.ref.update(update);
    }
  }

  console.log("");
  console.log(`${snap.size} technicians · ${linked} linked · ${stripped} passwords removed · ${roled} roles set${apply ? "" : " (dry run)"}`);
  if (missing.length) {
    console.log("\nCould not link (create their Auth login, then re-run):");
    missing.forEach((m) => console.log(`  - ${m}`));
  }
  if (!apply) console.log("\nRe-run with --apply to write these changes.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Migration failed:", e.message);
  process.exit(1);
});
