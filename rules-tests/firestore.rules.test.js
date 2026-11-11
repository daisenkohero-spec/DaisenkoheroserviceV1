// Firestore rules tests. Run from this folder: npm install && npm test
// (needs Java for the emulator). Uses a demo project — no real data touched.
const { test, before, beforeEach, after } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc, getDoc, getDocs, setDoc, updateDoc, addDoc, deleteDoc,
  collection, query, where, serverTimestamp,
} = require("firebase/firestore");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-dhs",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "technicians/techA"), { name: "A", phone: "0811111111", authUid: "uidA", password: "legacy" });
    await setDoc(doc(db, "technicians/techB"), { name: "B", phone: "0822222222", authUid: "uidB" });
    await setDoc(doc(db, "technicians/techUnlinked"), { name: "U", phone: "0833333333" });
    await setDoc(doc(db, "jobs/jobA"), { technicianId: "techA", status: "assigned", customer: "C1" });
    await setDoc(doc(db, "jobs/jobB"), { technicianId: "techB", status: "assigned", customer: "C2" });
    await setDoc(doc(db, "activity_events/evB"), { technicianId: "techB", type: "attendance_checkin" });
  });
});

after(async () => { await env.cleanup(); });

const as = (uid) => env.authenticatedContext(uid, { role: "technician" }).firestore();
const asAdmin = () => env.authenticatedContext("uidAdmin", { role: "admin" }).firestore();
const asNoRole = (uid) => env.authenticatedContext(uid).firestore();

// --- technicians ---------------------------------------------------------

test("technician reads own profile", async () => {
  await assertSucceeds(getDoc(doc(as("uidA"), "technicians/techA")));
});

test("login query by authUid succeeds", async () => {
  await assertSucceeds(getDocs(query(collection(as("uidA"), "technicians"), where("authUid", "==", "uidA"))));
});

test("technician cannot read another technician's profile", async () => {
  await assertFails(getDoc(doc(as("uidA"), "technicians/techB")));
});

test("self-signed-up stranger cannot read or list technicians", async () => {
  await assertFails(getDoc(doc(asNoRole("stranger"), "technicians/techA")));
  await assertFails(getDocs(collection(asNoRole("stranger"), "technicians")));
  await assertFails(getDocs(query(collection(asNoRole("stranger"), "technicians"), where("phone", "==", "0833333333"))));
});

test("stranger cannot claim an unlinked technician doc", async () => {
  await assertFails(updateDoc(doc(asNoRole("stranger"), "technicians/techUnlinked"), { authUid: "stranger" }));
});

test("technician updates own status and fcmToken", async () => {
  await assertSucceeds(updateDoc(doc(as("uidA"), "technicians/techA"), { status: "online", fcmToken: "t", lastLogin: serverTimestamp() }));
});

test("technician cannot change own authUid or phone", async () => {
  await assertFails(updateDoc(doc(as("uidA"), "technicians/techA"), { authUid: "other" }));
  await assertFails(updateDoc(doc(as("uidA"), "technicians/techA"), { phone: "0899999999" }));
});

test("nobody creates or deletes technicians from the app", async () => {
  await assertFails(setDoc(doc(as("uidA"), "technicians/new"), { name: "X", authUid: "uidA" }));
  await assertFails(deleteDoc(doc(as("uidA"), "technicians/techA")));
});

// --- jobs ----------------------------------------------------------------

test("technician reads and lists own jobs", async () => {
  await assertSucceeds(getDoc(doc(as("uidA"), "jobs/jobA")));
  await assertSucceeds(getDocs(query(collection(as("uidA"), "jobs"), where("technicianId", "==", "techA"))));
});

test("technician cannot read or update another technician's job", async () => {
  await assertFails(getDoc(doc(as("uidA"), "jobs/jobB")));
  await assertFails(updateDoc(doc(as("uidA"), "jobs/jobB"), { status: "completed" }));
});

test("technician cannot hand a job to someone else", async () => {
  await assertFails(updateDoc(doc(as("uidA"), "jobs/jobA"), { technicianId: "techB" }));
});

test("stranger cannot read any job", async () => {
  await assertFails(getDoc(doc(asNoRole("stranger"), "jobs/jobA")));
  await assertFails(getDocs(collection(asNoRole("stranger"), "jobs")));
});

// --- activity_events -----------------------------------------------------

test("technician logs an event about themselves", async () => {
  await assertSucceeds(addDoc(collection(as("uidA"), "activity_events"), { technicianId: "techA", type: "login" }));
});

test("technician cannot log events as someone else", async () => {
  await assertFails(addDoc(collection(as("uidA"), "activity_events"), { technicianId: "techB", type: "login" }));
});

test("technician cannot read another technician's events (GPS)", async () => {
  await assertFails(getDoc(doc(as("uidA"), "activity_events/evB")));
  await assertFails(getDocs(collection(asNoRole("stranger"), "activity_events")));
});

test("events are append-only", async () => {
  await assertFails(updateDoc(doc(as("uidB"), "activity_events/evB"), { type: "x" }));
  await assertFails(deleteDoc(doc(as("uidB"), "activity_events/evB")));
});

// --- admin role ----------------------------------------------------------

test("admin reads all technicians, jobs and events", async () => {
  await assertSucceeds(getDocs(collection(asAdmin(), "technicians")));
  await assertSucceeds(getDocs(collection(asAdmin(), "jobs")));
  await assertSucceeds(getDocs(collection(asAdmin(), "activity_events")));
});

test("admin creates, assigns and removes jobs", async () => {
  await assertSucceeds(setDoc(doc(asAdmin(), "jobs/new"), { technicianId: "techA", status: "assigned" }));
  await assertSucceeds(updateDoc(doc(asAdmin(), "jobs/jobA"), { technicianId: "techB" }));
  await assertSucceeds(deleteDoc(doc(asAdmin(), "jobs/jobB")));
});

test("admin manages technician profiles", async () => {
  await assertSucceeds(setDoc(doc(asAdmin(), "technicians/techNew"), { name: "N", phone: "0844444444" }));
  await assertSucceeds(updateDoc(doc(asAdmin(), "technicians/techB"), { radiusKm: 20 }));
});

test("admin cannot edit or delete the activity log", async () => {
  await assertFails(updateDoc(doc(asAdmin(), "activity_events/evB"), { type: "x" }));
  await assertFails(deleteDoc(doc(asAdmin(), "activity_events/evB")));
});

test("technicians and role-less accounts get no admin powers", async () => {
  await assertFails(setDoc(doc(as("uidA"), "jobs/new"), { technicianId: "techA" }));
  await assertFails(setDoc(doc(asNoRole("stranger"), "jobs/new"), { technicianId: "techA" }));
  await assertFails(getDocs(collection(asNoRole("stranger"), "technicians")));
  const fakeRole = env.authenticatedContext("stranger", { role: "Admin" }).firestore();
  await assertFails(getDocs(collection(fakeRole, "jobs")));
});

// --- default deny --------------------------------------------------------

test("unknown collections are denied", async () => {
  await assertFails(getDoc(doc(as("uidA"), "users/tech001")));
  await assertFails(setDoc(doc(as("uidA"), "anything/x"), { a: 1 }));
});
