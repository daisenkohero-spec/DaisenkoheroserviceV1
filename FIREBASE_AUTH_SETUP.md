# Firebase Auth + Security Rules — Setup & Migration

The app now authenticates technicians through **Firebase Authentication**
(Email/Password) instead of comparing plaintext passwords in Firestore. This
is what makes the Firestore/Storage security rules able to identify the user
(`request.auth`). Follow these steps once, in the `air-cleaning-test` project.

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

## 2. Create an Auth user for each technician

For every technician in the `technicians` collection, create a matching Auth
user (Console → Authentication → Users → Add user):

| Field | Value |
|-------|-------|
| Email | `<phone>@daisenkohero.local` |
| Password | the technician's existing password |

Example — for the dev technician (phone `0812345678`, password `1234`):

- Email: `0812345678@daisenkohero.local`
- Password: `1234`

### Linking `authUid`

On the technician's **first login**, the app automatically writes the new Auth
`uid` into their `technicians` doc as `authUid` (see `AuthRepository.login`).
The security rule allows this one-time claim only while `authUid` is unset.

If you prefer to avoid relying on the self-claim rule, set `authUid` manually on
each technician doc to the uid shown in the Authentication → Users list.

## 3. Remove plaintext passwords (after migration)

Once every technician can log in via Firebase Auth, delete the `password` field
from the `technicians` documents — it is no longer used and should not be stored.

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

- **technicians** — signed-in techs can read profiles; a tech can update only
  their own doc (matched by `authUid`); create/delete are console-only.
- **jobs** — a tech can read/update only jobs whose `technicianId` belongs to
  them; create/delete are console-only.
- **activity_events** — append-only: a tech can add events only about
  themselves; no edits or deletes.
- **storage `job_photos/`** — signed-in techs can read; uploads must be an
  image under 10 MB.

## Notes / caveats

- The first-login `authUid` self-claim rule lets any signed-in user claim a
  technician doc that has no `authUid` yet. For a small internal team this is
  low risk (each doc can only be claimed once). Set `authUid` manually in step 2
  if you want to remove that path entirely.
- If you later add an admin web dashboard, give it the Firebase **Admin SDK**
  (service account) — it bypasses these rules by design.
