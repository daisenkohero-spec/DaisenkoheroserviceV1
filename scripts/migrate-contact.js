// One-time: move each job's customer phone from the job document into
// jobs/{id}/private/contact, where technicians can only read it from 12 hours
// before the job until 24 hours after it is finished.
//
// Usage:
//   node migrate-contact.js            # dry run
//   node migrate-contact.js --apply    # move the phones
//
// Run it after deploying the app version that reads private/contact and the
// matching firestore.rules. Until then, older app builds read the phone from
// the job document directly.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const apply = process.argv.includes("--apply");

async function main() {
  const snap = await db.collection("jobs").get();
  let moved = 0;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snap.docs) {
    if (!doc.data().hasOwnProperty("phone")) continue;
    const phone = String(doc.get("phone") || "").trim();
    console.log(`${apply ? "MOVE" : "would move"} ${doc.id}${phone ? "" : " (empty phone, field removed only)"}`);
    moved++;
    if (!apply) continue;
    if (phone) {
      batch.set(doc.ref.collection("private").doc("contact"), { phone }, { merge: true });
      ops++;
    }
    batch.update(doc.ref, { phone: admin.firestore.FieldValue.delete() });
    ops++;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (apply && ops > 0) await batch.commit();

  console.log(`\n${snap.size} jobs · ${moved} ${apply ? "moved" : "to move (dry run)"}`);
  if (!apply && moved) console.log("Re-run with --apply to write these changes.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Migration failed:", e.message);
  process.exit(1);
});
