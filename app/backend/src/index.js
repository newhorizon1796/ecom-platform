import express from "express";
import cors from "cors";
import "dotenv/config";

import { productsRouter } from "./routes/products.js";
import { checkoutRouter } from "./routes/checkout.js";
import { pingDb } from "./db.js";

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

// Liveness/readiness — used by k8s probes once Helm charts exist.
app.get("/healthz", (req, res) => res.json({ status: "ok" }));

app.get("/readyz", async (req, res) => {
  try {
    await pingDb();
    res.json({ status: "ready" });
  } catch (err) {
    res.status(503).json({ status: "not ready", error: err.message });
  }
});

app.use("/api/products", productsRouter);
app.use("/api/checkout", checkoutRouter);

app.listen(PORT, () => {
  console.log(`ecom-platform backend listening on :${PORT}`);
});
