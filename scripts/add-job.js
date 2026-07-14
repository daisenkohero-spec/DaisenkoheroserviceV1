// Daily job creator for the pilot (interim dispatcher).
//
// Usage:
//   node add-job.js <techPhone> "<customer>" "<service>" <start HH:MM> <end HH:MM> [place] [customerPhone]
//
// Examples:
//   node add-job.js 0811112222 "คุณสมชาย" "ล้างแอร์" 09:00 11:00
//   node add-job.js 0811112222 "คุณสมหญิง" "ล้างแอร์ 2 เครื่อง" 13:00 15:00 "คอนโด ABC ห้อง 502" 0898887777
//
// Assigns the job to the technician with that phone number (must already be
// onboarded via add-technician.js). Creates the job for TODAY so it appears under
// "Today's Jobs" in that technician's app.

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function technicianIdForPhone(phone) {
  const snap = await db
    .collection("technicians")
    .where("phone", "==", String(phone).trim())
    .limit(1)
    .get();
  if (snap.empty) {
    console.error(
      `No technician with phone ${phone}. Onboard them first: node add-technician.js "<name>" ${phone} <password>`
    );
    process.exit(1);
  }
  return snap.docs[0].id;
}

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
  const [techPhone, customer, service, startStr, endStr, place, phone] =
    process.argv.slice(2);

  if (!techPhone || !customer || !service || !startStr || !endStr) {
    console.error(
      'Usage: node add-job.js <techPhone> "<customer>" "<service>" <start HH:MM> <end HH:MM> [place] [customerPhone]'
    );
    process.exit(1);
  }

  const technicianId = await technicianIdForPhone(techPhone);
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
    technicianId,
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
