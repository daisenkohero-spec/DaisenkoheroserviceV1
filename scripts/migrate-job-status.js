// One-time migration of job statuses to the booking-system names (admin tool).
//
// Usage:
//   node migrate-job-status.js            # dry run
//   node migrate-job-status.js --apply    # writes the changes
//
// Old values the technician app used to write:
//   pending, accepted → assigned   (a job the office had already given a technician)
//   overdue           → assigned   (overdue is now computed from endTime, not stored)
// Each changed job gets a `timeline` entry recording the migration.
// Jobs already on a current status are left alone. The app reads the old values
// correctly either way, so this can run any time after the app update ships.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const apply = process.argv.includes("--apply");
const LEGACY = { pending: "assigned", accepted: "assigned", overdue: "assigned" };

async function main() {
  const snap = await db.collection("jobs").where("status", "in", Object.keys(LEGACY)).get();
  const counts = {};
  let batch = db.batch();
  let inBatch = 0;

  for (const doc of snap.docs) {
    const from = doc.get("status");
    const to = LEGACY[from];
    counts[`${from} → ${to}`] = (counts[`${from} → ${to}`] || 0) + 1;
    console.log(`${apply ? "UPDATE" : "would update"} ${doc.id}: ${from} → ${to}`);
    if (!apply) continue;
    batch.update(doc.ref, {
      status: to,
      timeline: admin.firestore.FieldValue.arrayUnion({
        status: to,
        at: admin.firestore.Timestamp.now(),
        by: `migration:${from}`,
      }),
    });
    if (++inBatch === 400) {
      await batch.commit();
      batch = db.batch();
      inBatch = 0;
    }
  }
  if (apply && inBatch > 0) await batch.commit();

  console.log("");
  console.log(`${snap.size} jobs on old statuses${apply ? " migrated" : " (dry run)"}`);
  Object.entries(counts).forEach(([k, v]) => console.log(`  ${k}: ${v}`));
  if (!apply && snap.size) console.log("\nRe-run with --apply to write these changes.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Migration failed:", e.message);
  process.exit(1);
});
