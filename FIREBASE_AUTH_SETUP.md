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

## 4b. Roles: admins and technicians

Each login carries a `role` custom claim: `technician` or `admin`. Only the
Admin SDK can set it, so a self-created account can't promote itself.

- `add-technician.js` and `migrate-auth.js --apply` give technicians their role.
- Office staff (real email addresses):

```powershell
cd scripts
node set-role.js office@example.com admin --create <password>   # new admin
node set-role.js owner@example.com admin                        # existing login
node set-role.js office@example.com none                        # remove admin
```

A role change takes effect after the person signs out and back in. An admin
without a technician profile who opens the technician app sees
"บัญชีนี้เป็นบัญชีแอดมิน กรุณาใช้หน้าหลังบ้าน".

## 4c. Sign in with Google (optional, per technician)

A technician signs in with phone + password once, taps their name on the Home
screen → **เชื่อมบัญชี Google**, and picks a Google account. That Google account
is linked to the *same* Firebase user, so `authUid`, roles and rules are
unchanged. After that the **เข้าสู่ระบบด้วย Google** button on the login screen
works for them.

A Google account that was never linked signs in to an empty Firebase user; the
app deletes that user and shows "บัญชี Google นี้ยังไม่ได้เชื่อมกับช่าง…". It can
never reach a technician's data.

One-time console setup:

1. **Authentication → Sign-in method → Add new provider → Google → Enable**,
   pick a support email, Save.
2. **Web:** works on `localhost` and the Firebase Hosting domains out of the box.
   Add any other domain under Authentication → Settings → Authorized domains.
3. **Android:** add the app's SHA-1 fingerprints under Project settings → General
   → Your apps → Android app → *Add fingerprint*. Get them with:

   ```powershell
   cd android
   .\gradlew signingReport
   ```

   Add the SHA-1 of the `debug` variant (for `flutter run`) and of the release
   keystore (for Play Store builds). Play Store builds signed by Google Play
   also need the *App signing key* SHA-1 from Play Console → Setup → App
   signing. Without these, the Google button fails on Android only.

To unlink a technician's Google account (e.g. a lost Google account), run in
`scripts/` with their phone number:

```powershell
node -e "const a=require('firebase-admin');a.initializeApp({credential:a.credential.cert(require('./serviceAccountKey.json'))});a.auth().getUserByEmail('0812345678@daisenkohero.local').then(u=>a.auth().updateUser(u.uid,{providersToUnlink:['google.com']})).then(()=>{console.log('unlinked');process.exit(0)})"
```

## 5. What the rules enforce

- **technicians** — a tech can read and update only their own doc (matched by
  `authUid`) and cannot change `authUid` or `phone`. Admins read and manage all.
- **jobs** — a tech can read/update only jobs whose `technicianId` belongs to
  them and cannot reassign a job. Admins create, assign, edit and delete any job.
- **activity_events** — append-only: a tech can add and read only their own
  events; admins read all. Nobody edits or deletes.
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
- Server-side code using the Firebase **Admin SDK** (scripts, Cloud Functions)
  bypasses these rules by design.
