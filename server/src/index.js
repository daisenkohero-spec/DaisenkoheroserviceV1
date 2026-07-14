require("dotenv").config();

const express = require("express");
const cors = require("cors");
const authRoutes = require("./routes/auth");
const jobRoutes = require("./routes/jobs");

const app = express();
const port = Number(process.env.PORT ?? 3000);
const apiPrefix = process.env.API_PREFIX ?? "/api";
const corsOrigin = process.env.CORS_ORIGIN ?? "http://localhost:8080";

app.use(
  cors({
    origin: corsOrigin,
    credentials: true,
  }),
);
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "Daisenko Hero Service API",
    timestamp: new Date().toISOString(),
  });
});

app.use(apiPrefix, authRoutes);
app.use(apiPrefix, jobRoutes);

app.use((req, res) => {
  res.status(404).json({
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

app.listen(port, () => {
  console.log(`Daisenko Hero Service API running at http://localhost:${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
  console.log(`API base URL: http://localhost:${port}${apiPrefix}`);
});
