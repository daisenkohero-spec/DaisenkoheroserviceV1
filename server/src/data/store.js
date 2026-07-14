const technicians = [
  {
    id: "tech001",
    name: "ช่างทดสอบ",
    phone: "0812345678",
    password: "1234",
  },
];

const jobs = [
  {
    id: "job001",
    technicianId: "tech001",
    date: "2026-06-08",
    month: "June",
    start: "09:00",
    end: "11:00",
    service: "ล้างแอร์",
    customer: "คุณสมชาย",
    phone: "0899999999",
    place: "บ้านเลขที่ 12 ซอยสุขุม",
    location: "กรุงเทพฯ",
    serviceType: "แอร์บ้าน",
    status: "assigned",
    notificationType: "newJob",
    priority: "normal",
    isNotificationRead: false,
    createdAt: new Date().toISOString(),
    startTime: new Date("2026-06-08T09:00:00").toISOString(),
    endTime: new Date("2026-06-08T11:00:00").toISOString(),
  },
];

const sessions = new Map();
const checkins = [];

function createToken(technicianId) {
  const token = `dhs_${technicianId}_${Date.now()}`;
  sessions.set(token, technicianId);
  return token;
}

function getTechnicianByToken(token) {
  const technicianId = sessions.get(token);
  if (!technicianId) {
    return null;
  }

  return technicians.find((tech) => tech.id === technicianId) ?? null;
}

module.exports = {
  technicians,
  jobs,
  checkins,
  createToken,
  getTechnicianByToken,
};
