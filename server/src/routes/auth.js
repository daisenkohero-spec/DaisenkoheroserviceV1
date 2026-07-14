const express = require("express");
const {
  technicians,
  createToken,
  getTechnicianByToken,
} = require("../data/store");

const router = express.Router();

router.post("/login", (req, res) => {
  const { phone, password } = req.body ?? {};

  if (!phone || !password) {
    return res.status(400).json({ message: "phone and password are required" });
  }

  const technician = technicians.find((tech) => tech.phone === phone);

  if (!technician || technician.password !== password) {
    return res.status(401).json({ message: "Invalid phone or password" });
  }

  const token = createToken(technician.id);

  return res.json({
    id: technician.id,
    name: technician.name,
    token,
  });
});

router.get("/profile", (req, res) => {
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

  return res.json({
    id: technician.id,
    name: technician.name,
    token,
  });
});

module.exports = router;
