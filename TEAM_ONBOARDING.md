# Rolling the app out to the service team

Interim admin tooling (until a proper admin UI is built). All commands run from the
`scripts/` folder and require `scripts/serviceAccountKey.json` (the Firebase Admin key,
kept out of git) and Node.js installed.

## 1. Onboard each technician (once per person)

```
node add-technician.js "<name>" <phone> <password>
```

Example:
```
node add-technician.js "ช่างสมชาย" 0811112222 pilot2026
```

This creates the login **and** the technician profile in one step. Then give that
technician **their phone number + password** — that's what they type into the app at
`https://daisenkoheroservicev1.web.app`.

- Password must be ≥ 6 characters.
- Each technician's login email is their phone: `<phone>@daisenkohero.local` (handled
  automatically — the technician only ever types their phone number).

## 2. Assign jobs each day

```
node add-job.js <techPhone> "<customer>" "<service>" <start> <end> [address] [customerPhone]
```

Examples:
```
node add-job.js 0811112222 "คุณสมชาย" "ล้างแอร์" 09:00 11:00
node add-job.js 0811112222 "คุณสมหญิง" "ล้างแอร์ 2 เครื่อง" 13:00 15:00 "คอนโด ABC ห้อง 502" 0898887777
```

The job is created for **today** and appears under "Today's Jobs" in that technician's
app. The technician must already be onboarded (step 1).

## 3. Password resets

Synthetic emails can't receive reset links, so resets are admin-only for now:
Firebase console → Authentication → Users → find the user → reset password. (A reset
helper script can be added later if needed.)

## ⚠️ Before real staff and customer data goes in — PDPA
This app records **technician GPS/location, attendance, and customer personal data**.
Under Thailand's PDPA you should have a **privacy notice and consent** (especially for
location tracking of staff) before rolling out widely. Add a privacy/consent screen — see
LAUNCH_CHECKLIST.md.

## What's still manual / missing
- No self-service password reset for technicians.
- No admin UI — onboarding and job assignment are these command-line scripts.
- Finish-job photos need the Blaze plan (Firebase Storage).
