import { Router } from "express";
import { pool } from "../db.js";

export const checkoutRouter = Router();

// POST /api/checkout
// body: { items: [{ product_id, quantity }], discount_code?: string }
//
// Cart is client-held (no server-side cart session) — simple, real-world
// enough pattern for a practice app. Server is the source of truth for
// price/discount math so a tampered client can't set its own total.
checkoutRouter.post("/", async (req, res) => {
  const { items, discount_code } = req.body;

  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "Cart is empty" });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Look up current price/stock for every line item server-side.
    const productIds = items.map((i) => i.product_id);
    const [products] = await conn.query(
      `SELECT id, name, price_cents, stock FROM products WHERE id IN (?)`,
      [productIds]
    );
    const productById = Object.fromEntries(products.map((p) => [p.id, p]));

    let subtotalCents = 0;
    const lineItems = [];

    for (const item of items) {
      const product = productById[item.product_id];
      if (!product) {
        throw new Error(`Product ${item.product_id} not found`);
      }
      if (item.quantity < 1) {
        throw new Error(`Invalid quantity for ${product.name}`);
      }
      if (product.stock < item.quantity) {
        throw new Error(`Insufficient stock for ${product.name}`);
      }

      const lineTotalCents = product.price_cents * item.quantity;
      // Summed across every line item — this is the actual cart subtotal,
      // not just one item's price. (Yes, this comment exists because a
      // version of this exact bug is what the Jira ticket-practice EP-1
      // simulated — worth getting right for real here.)
      subtotalCents += lineTotalCents;

      lineItems.push({
        product_id: product.id,
        name: product.name,
        unit_price_cents: product.price_cents,
        quantity: item.quantity,
        line_total_cents: lineTotalCents,
      });
    }

    // Discount, applied once to the summed subtotal, not per line item.
    let discountPercent = 0;
    if (discount_code) {
      const [codes] = await conn.query(
        "SELECT percent_off FROM discount_codes WHERE code = ? AND active = 1",
        [discount_code]
      );
      if (codes.length === 0) {
        throw new Error(`Invalid or inactive discount code: ${discount_code}`);
      }
      discountPercent = codes[0].percent_off;
    }

    const discountCents = Math.round(subtotalCents * (discountPercent / 100));
    const totalCents = subtotalCents - discountCents;

    const [orderResult] = await conn.query(
      `INSERT INTO orders (subtotal_cents, discount_cents, total_cents, discount_code)
       VALUES (?, ?, ?, ?)`,
      [subtotalCents, discountCents, totalCents, discount_code || null]
    );
    const orderId = orderResult.insertId;

    for (const li of lineItems) {
      await conn.query(
        `INSERT INTO order_items (order_id, product_id, unit_price_cents, quantity, line_total_cents)
         VALUES (?, ?, ?, ?, ?)`,
        [orderId, li.product_id, li.unit_price_cents, li.quantity, li.line_total_cents]
      );
      await conn.query("UPDATE products SET stock = stock - ? WHERE id = ?", [
        li.quantity,
        li.product_id,
      ]);
    }

    await conn.commit();

    res.status(201).json({
      order_id: orderId,
      items: lineItems,
      subtotal_cents: subtotalCents,
      discount_percent: discountPercent,
      discount_cents: discountCents,
      total_cents: totalCents,
    });
  } catch (err) {
    await conn.rollback();
    console.error("POST /api/checkout failed:", err.message);
    res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});
