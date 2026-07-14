const express = require("express");
const { jobs, checkins, getTechnicianByToken } = require("../data/store");

const router = express.Router();

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  if (!token) {
    return res.status(401).json({ message: "Unauthorized" });
  }

  const technician = getTechnicianByToken(token);

  if (!technician) {
    return res.status(401).json({ message: "Unauthorized" });
  }

  req.technician = technician;
  return next();
}

router.get("/jobs", requireAuth, (req, res) => {
  const technicianJobs = jobs.filter(
    (job) => job.technicianId === req.technician.id,
  );

  return res.json({ data: technicianJobs });
});

router.get("/notifications", requireAuth, (req, res) => {
  const notifications = jobs
    .filter(
      (job) =>
        job.technicianId === req.technician.id &&
        job.notificationType !== "none" &&
        job.isNotificationRead === false,
    )
    .map((job) => ({
      id: job.id,
      title: job.notificationType === "newJob" ? "งานใหม่" : "อัปเดตงาน",
      message: job.service,
      jobId: job.id,
    }));

  return res.json({ data: notifications });
});

router.post("/checkin", requireAuth, (req, res) => {
  const { jobId, latitude, longitude } = req.body ?? {};

  if (!jobId || latitude == null || longitude == null) {
    return res
      .status(400)
      .json({ message: "jobId, latitude, and longitude are required" });
  }

  const job = jobs.find(
    (item) => item.id === jobId && item.technicianId === req.technician.id,
  );

  if (!job) {
    return res.status(404).json({ message: "Job not found" });
  }

  const record = {
    id: `checkin_${Date.now()}`,
    jobId,
    technicianId: req.technician.id,
    latitude,
    longitude,
    checkedInAt: new Date().toISOString(),
  };

  checkins.push(record);
  job.status = "working";
  job.isNotificationRead = true;
  job.startedWorkingAt = new Date().toISOString();

  return res.json({ data: record, job });
});

router.post("/finish-job", requireAuth, (req, res) => {
  const { jobId, imagePath, note } = req.body ?? {};

  if (!jobId) {
    return res.status(400).json({ message: "jobId is required" });
  }

  const job = jobs.find(
    (item) => item.id === jobId && item.technicianId === req.technician.id,
  );

  if (!job) {
    return res.status(404).json({ message: "Job not found" });
  }

  job.status = "completed";
  job.finishedAt = new Date().toISOString();
  job.notificationType = "jobUpdate";
  job.isNotificationRead = false;
  if (imagePath) {
    job.imagePath = imagePath;
  }
  if (note) {
    job.note = note;
  }

  return res.json({ data: job });
});

module.exports = router;
