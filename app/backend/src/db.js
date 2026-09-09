import mysql from "mysql2/promise";

// Connection pool — reads from env vars, populated locally via docker-compose's
// environment block, and in-cluster via the External Secrets Operator-synced
// Secret (see helm/values/*.yaml) once we get to the Helm deploy phase.
export const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "ecom",
  // EP-2 fix: without an explicit charset, multi-byte data (emoji, etc.)
  // can get mangled on read/write depending on driver/server negotiation
  // defaults. Force it rather than relying on defaults matching up.
  charset: "utf8mb4",
  waitForConnections: true,
  connectionLimit: 10,
});

export async function pingDb() {
  const [rows] = await pool.query("SELECT 1 AS ok");
  return rows[0].ok === 1;
}
