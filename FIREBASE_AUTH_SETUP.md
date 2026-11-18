# Firebase Auth + Security Rules — Setup & Migration

The app now authenticates technicians through **Firebase Authentication**
(Email/Password) instead of comparing plaintext passwords in Firestore. This
is what makes the Firestore/Storage security rules able to identify the user
(`request.auth`). Follow these steps once, in the `daisenkoheroservicev1` project.

## Why this changed

Previously login read the `technicians` collection directly and compared a
plaintext `password` field, so Firebase never knew who the user was and the
rules had to be wide open. Now:

- Password verification happens in Firebase Auth (hashed, not plaintext).
- Each technician's Firestore doc is linked to their Auth account via an
  `authUid` field.
- The technician's phone number maps to a synthetic login email:
  `"<phone>@daisenkohero.local"` (e.g. `0812345678@daisenkohero.local`).

## 1. Enable the Email/Password sign-in provider

Firebase Console → **Authentication** → **Sign-in method** →
enable **Email/Password**.

## 2. Create the Auth login for each technician

**New technicians** — one command creates the Auth login *and* the linked
`technicians` doc (needs `scripts/serviceAccountKey.json`, never committed):

```powershell
cd scripts
npm install
node add-technician.js "ช่างสมชาย" 0811112222 <password>
```

**Existing technicians** (docs created before Firebase Auth) — create their Auth
user in Console → Authentication → Users → Add user:

| Field | Value |
|-------|-------|
| Email | `<phone>@daisenkohero.local` |
| Password | a new password (at least 6 characters) |

## 3. Link `authUid` and remove plaintext passwords

The app does **not** link accounts on first login: anyone with the app's public
config can create a Firebase Auth account, so a self-claim path would let a
stranger take over any unlinked technician. Linking is done by admin tooling only.

```powershell
cd scripts
node migrate-auth.js            # dry run — review the output
node migrate-auth.js --apply    # link authUid + delete every `password` field
```

The script lists any technician it could not link (no Auth user yet). Create
their login, then run it again. Until a technician is linked, login shows
"ไม่พบผู้ใช้งานนี้".

## 4. Deploy the security rules

Rules live in this repo (`firestore.rules`, `storage.rules`, wired via
`firebase.json`). Deploy them:

```powershell
npm install -g firebase-tools   # if not already installed
firebase login
firebase deploy --only firestore:rules,storage
```

`firebase deploy --only storage` also requires that a **Storage bucket** exists:
Console → **Storage** → **Get started** (if you haven't already).

## 5. What the rules enforce

- **technicians** — a tech can read and update only their own doc (matched by
  `authUid`) and cannot change `authUid` or `phone`; create/delete are Admin SDK only.
- **jobs** — a tech can read/update only jobs whose `technicianId` belongs to
  them and cannot reassign a job; create/delete are Admin SDK only.
- **activity_events** — append-only: a tech can add and read only their own events.
- **everything else** — denied.
- **storage `job_photos/`** — signed-in techs can read; uploads must be an
  image under 10 MB.

Being signed in is never enough on its own: a self-created Auth account that no
technician doc points at can read nothing.

## 6. Test the rules locally

Needs Node and Java (for the emulator). Uses a demo project, no real data:

```powershell
cd rules-tests
npm install
npm test
```

## Notes / caveats

- Storage `job_photos/` still lets any signed-in user upload to any job's
  folder; restrict it to the job's technician when the booking system lands.
- Firebase Storage and Cloud Functions need the **Blaze** plan.
- If you later add an admin web dashboard, give admins a custom claim
  (`role: admin`) and grant access in these rules; server-side code using the
  Firebase **Admin SDK** bypasses rules by design.
