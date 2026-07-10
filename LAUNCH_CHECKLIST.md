# Launch Checklist — Daisenko Hero Service (web)

Production-readiness gaps, grouped by priority. Check off as completed.

## Tier 1 — Blockers to go live
- [ ] **Host the web app.** `flutter build web --release` → `firebase deploy --only hosting`
      (Firebase Hosting, gives `daisenkoheroservicev1.web.app` + HTTPS). *(in progress)*
- [ ] **Technician onboarding process.** Each tech needs a Firebase Auth user
      (`<phone>@daisenkohero.local`) + a `technicians` doc (matching `phone`).
      Document or build an admin action for this.
- [ ] **Firebase Storage (photos).** Requires upgrading to the **Blaze** plan, then
      `firebase deploy --only storage`. Needed only if proof-of-work photos ship.

## Tier 2 — Needed to actually be usable
- [ ] **Job dispatcher.** No way to create/assign jobs today (jobs are hand-typed in
      the console). Build a minimal admin screen or booking intake — the technician
      app is empty without it.
- [ ] **Web push notifications.** Broken on web: missing `web/firebase-messaging-sw.js`
      service worker + VAPID key. Technicians currently get no "new job" alerts on web.
- [ ] **Password reset.** Synthetic emails (`@daisenkohero.local`) can't receive reset
      emails — forgotten passwords require an admin reset in the console. Plan the
      support process (or move to real emails).

## Tier 3 — Production hygiene & trust
- [ ] **Revert pilot geofence.** `AttendanceProvider.allowedRadius` is 50 km for testing —
      set back to the real value (~100 m), ideally a config value, before production.
- [ ] **Remove dead backend code.** Unused `ApiClient` (points at `localhost:3000` /
      nonexistent `api.daisenkohero.com`) and the parked Node `server/`.
- [ ] **Strip debug `print` statements** across `lib/` (they leak to the browser console).
- [ ] **Error monitoring.** Add Crashlytics or Sentry so field failures are visible.
- [ ] **App Check.** Firebase keys ship in the public web bundle; App Check guards against
      abuse of your database/quota.

## Legal / compliance (Thailand PDPA) — do not skip
- [ ] **Privacy notice + consent.** The app collects GPS location, attendance, and
      personal data on staff and customers. PDPA requires a privacy notice and explicit
      consent, especially for location tracking. Add a privacy policy page and a
      location-consent screen.

## Recommended sequence
1. Deploy to Hosting (Tier 1) → real URL to share.
2. Decide Blaze for photos (Tier 1).
3. Build the job dispatcher (Tier 2).
4. PDPA notice + location consent (Legal).
5. Then before wider/customer release: web push, revert radius, remove dead code,
   error monitoring, App Check.
