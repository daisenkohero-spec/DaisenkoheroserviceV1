# Pilot — Daily Job Entry Template

Until the job dispatcher is built, add each day's jobs by hand in the Firestore
console. It takes ~1 minute per job.

## How to add a job
1. Firebase console → **Firestore** → open the **`jobs`** collection
   (click **Start collection** → ID `jobs` the very first time).
2. Click **Add document** → **Auto-ID**.
3. Add the fields below.

## Fields

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `technicianId` | string | `pT7q587VHekQgDzS02MP` | **Must equal the technician's document ID** — this is who the job appears for. |
| `customer` | string | `คุณสมชาย` | Customer name |
| `phone` | string | `0899999999` | Customer phone |
| `service` | string | `ล้างแอร์` | What the job is |
| `serviceType` | string | `แอร์บ้าน` | Category |
| `place` | string | `บ้านเลขที่ 12 ซอยสุขุมวิท 21` | Full address |
| `location` | string | `กรุงเทพฯ` | Area / district |
| `mapUrl` | string | `13.7563,100.5018` | Customer location as `lat,lng` (for in-app navigation) |
| `date` | string | `2026-07-11` | Shown on the card |
| `month` | string | `July` | Shown on the card |
| `start` | string | `09:00` | Display start time |
| `end` | string | `11:00` | Display end time |
| `startTime` | **timestamp** | today @ 09:00 | **Drives "Today's Jobs".** Use the picker, set today's date + start time. |
| `endTime` | **timestamp** | today @ 11:00 | Drives overdue / duration. Today's date + end time. |
| `createdAt` | **timestamp** | now | |
| `status` | string | `assigned` | Job state (`assigned` = upcoming) |
| `notificationType` | string | `newJob` | Triggers the "new job" alert |
| `priority` | string | `normal` | `low` / `normal` / `high` / `urgent` |
| `isNotificationRead` | boolean | `false` | |

## Critical points
- **`technicianId` must exactly match the technician's Firestore doc ID.** Find it
  in the `technicians` collection (the current test tech is `pT7q587VHekQgDzS02MP`).
- **`startTime` / `endTime` are `timestamp` type, not string.** Set them to *today*
  with the job's real times, or the job won't appear under "Today's Jobs."
- Set `status` to `assigned` for a new upcoming job.
