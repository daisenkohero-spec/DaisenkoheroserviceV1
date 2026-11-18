// Create config/booking with the spec's default booking settings (admin tool).
//
// Usage:
//   node init-config.js            # dry run: shows what would be added
//   node init-config.js --apply    # writes missing keys only
//
// Existing values are never overwritten, so it is safe to re-run after
// admins have changed settings in the dashboard.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const apply = process.argv.includes("--apply");

// Values from the spec ("หลังบ้านแอดมินและค่าคอนฟิก").
const DEFAULTS = {
  inspectionFeeBaht: 500, // ค่าตรวจเช็กงานซ่อม
  repairApprovalLimitBaht: 3000, // ใบเสนอราคาเกินนี้ต้องให้แอดมินอนุมัติ
  slots: [
    { id: "morning", start: "09:00", end: "12:00", maxUnits: 3 },
    { id: "afternoon", start: "13:00", end: "16:00", maxUnits: 3 },
    { id: "evening", start: "16:00", end: "18:00", maxUnits: 2 },
  ],
  twoSlotUnits: { min: 4, max: 6 }, // 4–6 เครื่องใช้ 2 ช่วงต่อเนื่อง
  adminOnlyAboveUnits: 6, // มากกว่านี้ส่งแอดมินจัดทีม
  bookingWindowDays: { min: 1, max: 14 },
  slotHoldMinutes: 15,
  defaultRadiusKm: 15,
  dispatchExpandAfterMinutes: 15,
  dispatchToAdminAfterMinutes: 30,
  cancelCutoffHours: 24,
  autoCloseHours: 24,
  certValidMonths: 12,
  certReminderDays: 30,
  contactWindow: { hoursBefore: 12, hoursAfterFinish: 24 },
};

async function main() {
  const ref = db.collection("config").doc("booking");
  const current = (await ref.get()).data() || {};
  const missing = Object.fromEntries(
    Object.entries(DEFAULTS).filter(([k]) => !(k in current)),
  );
  const keys = Object.keys(missing);
  if (!keys.length) {
    console.log("config/booking already has every setting. Nothing to do.");
    process.exit(0);
  }
  keys.forEach((k) => console.log(`${apply ? "ADD" : "would add"} ${k} = ${JSON.stringify(missing[k])}`));
  if (apply) await ref.set(missing, { merge: true });
  console.log(`\n${keys.length} setting(s) ${apply ? "added" : "to add (dry run)"}`);
  process.exit(0);
}

main().catch((e) => {
  console.error("Failed:", e.message);
  process.exit(1);
});
