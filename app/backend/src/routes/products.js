import { Router } from "express";
import { pool } from "../db.js";

export const productsRouter = Router();

productsRouter.get("/", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT id, name, description, price_cents, image_emoji, stock FROM products ORDER BY id"
    );
    res.json(rows);
  } catch (err) {
    console.error("GET /api/products failed:", err.message);
    res.status(500).json({ error: "Failed to load products" });
  }
});

productsRouter.get("/:id", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT id, name, description, price_cents, image_emoji, stock FROM products WHERE id = ?",
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "Product not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error("GET /api/products/:id failed:", err.message);
    res.status(500).json({ error: "Failed to load product" });
  }
});
