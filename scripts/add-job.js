// Daily job creator for the pilot (interim dispatcher).
//
// Usage:
//   node add-job.js "<customer>" "<service>" <start HH:MM> <end HH:MM> [place] [phone] [technicianId]
//
// Examples:
//   node add-job.js "คุณสมชาย" "ล้างแอร์" 09:00 11:00
//   node add-job.js "คุณสมหญิง" "ล้างแอร์ 2 เครื่อง" 13:00 15:00 "คอนโด ABC ห้อง 502" 0898887777
//
// Creates a job for TODAY, assigned to the given technician (default = test tech),
// so it appears under "Today's Jobs" in the app.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Default technician (the pilot test tech). Override with the 7th argument.
const DEFAULT_TECHNICIAN_ID = "pT7q587VHekQgDzS02MP";

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

function parseHHMM(label, value) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value || "");
  if (!m) {
    console.error(`Invalid ${label} time "${value}". Use HH:MM, e.g. 09:00`);
    process.exit(1);
  }
  return { h: Number(m[1]), min: Number(m[2]) };
}

async function main() {
  const [customer, service, startStr, endStr, place, phone, techId] =
    process.argv.slice(2);

  if (!customer || !service || !startStr || !endStr) {
    console.error(
      'Usage: node add-job.js "<customer>" "<service>" <start HH:MM> <end HH:MM> [place] [phone] [technicianId]'
    );
    process.exit(1);
  }

  const start = parseHHMM("start", startStr);
  const end = parseHHMM("end", endStr);

  const now = new Date();
  const y = now.getFullYear();
  const mo = now.getMonth();
  const d = now.getDate();

  const startTime = new Date(y, mo, d, start.h, start.min, 0);
  const endTime = new Date(y, mo, d, end.h, end.min, 0);
  const dateStr = `${y}-${String(mo + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

  const job = {
    technicianId: techId || DEFAULT_TECHNICIAN_ID,
    customer,
    phone: phone || "",
    service,
    serviceType: service,
    place: place || "",
    location: place || "",
    mapUrl: null,
    date: dateStr,
    month: MONTHS[mo],
    start: startStr,
    end: endStr,
    startTime: admin.firestore.Timestamp.fromDate(startTime),
    endTime: admin.firestore.Timestamp.fromDate(endTime),
    createdAt: admin.firestore.Timestamp.fromDate(now),
    status: "assigned",
    notificationType: "newJob",
    priority: "normal",
    isNotificationRead: false,
  };

  const ref = await db.collection("jobs").add(job);
  console.log(`✓ Job created: ${ref.id}`);
  console.log(
    `  ${customer} — ${service}  |  ${dateStr} ${startStr}-${endStr}  |  tech ${job.technicianId}`
  );
  process.exit(0);
}

main().catch((e) => {
  console.error("Failed to create job:", e.message);
  process.exit(1);
});
