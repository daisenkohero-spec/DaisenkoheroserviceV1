# Admin Dispatcher — Scope (v1)

The office-facing "control panel" for Daisenko Hero Service. Turns the current
terminal scripts into a web tool and adds the management/reporting view.

## Goal
Let the office run daily operations from a browser: assign jobs, see the team and
today's work, onboard technicians, and read the data the app collects — without any
terminal commands.

## Users
- **Admins** = the owner + a few office/dispatch staff. Multiple admin accounts.
- Admins are separate from technicians. Admins see the dispatcher; technicians see the
  existing technician app.

## Decisions locked
- **Multiple admin users** (owner + office staff).
- **Reporting included in v1** (data dashboard, not just job entry).
- **Jobs are entered by the office** — no customer-facing online booking in v1.

## In scope (v1)

### A. Admin access
- Admin login (Firebase Auth). At login the app checks whether the user is an admin
  (an `admins` collection) and shows the dispatcher instead of the technician view.
- An `add-admin` script (Admin SDK) to create admin accounts, mirroring
  `add-technician.js`.

### B. Job assignment
- Form to create a job: customer, service, date/time, address, **pick a technician**
  from a dropdown. Replaces `add-job.js`.
- Basic validation and a confirmation.

### C. Today's board
- All of today's jobs across the whole team, grouped by status:
  assigned / working / done / overdue. Live-updating.

### D. Technician management
- List of technicians with online / checked-in-today status.
- Form to onboard a new technician (replaces `add-technician.js`).

### E. Reporting dashboard
- For a selectable date range (this week / month / custom):
  - Attendance rate per technician (present / late / leave)
  - Jobs completed per technician
  - Average on-site time per job
- Reads from the existing `activity_events` + `jobs` data — the pipeline is already
  collecting this.

## Out of scope (later versions)
- **v1.1:** edit / reschedule / cancel jobs; job detail view with photos.
- **v2:** deeper analytics (trends over time, maps of job locations, exports).
- **Separate module:** customer-facing online booking.
- Payroll, invoicing, customer CRM.

## Technical approach
- **Reuse everything:** same Firebase project (`daisenkoheroservicev1`), same data
  models, same auth. No second system.
- **Same app, role-based:** at login, route admins to the dispatcher screens and
  technicians to the current app. One codebase, one deployment.
- **New pieces required:**
  - `admins/{uid}` collection to mark admin users.
  - Security-rules update so admins can create/assign jobs and read all
    technicians / jobs / activity_events (technicians stay scoped to their own data).
  - Firestore composite indexes for the reporting queries (e.g. `jobs` by
    technicianId + date, `activity_events` by type + timestamp).
  - A charting approach for the dashboard.

## Proposed build phases
0. **Foundations** — admins collection + `add-admin` script, security-rules update,
   role-based routing at login.
1. **Job assignment** — create/assign form + today's board.
2. **Technician management** — list + onboard form + status.
3. **Reporting dashboard** — attendance, jobs/tech, on-site time.

## Effort (rough)
A focused v1 with reporting is on the order of **1–2 weeks** of development, best done
phase by phase so each piece is usable as it lands.

## Dependencies / notes
- **PDPA:** collecting real staff GPS + customer data — privacy notice + consent still
  required before wide rollout (see LAUNCH_CHECKLIST.md).
- Security-rules changes are the riskiest part (they gate all data access) — test
  carefully so technicians keep seeing only their own data.
- Best built on a new branch, merged when a phase is verified.
