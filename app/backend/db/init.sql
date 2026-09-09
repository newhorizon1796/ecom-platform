-- Local dev schema + seed data. Mounted into the MySQL container via
-- docker-compose (docker-entrypoint-initdb.d runs this automatically on
-- first container start). Same schema gets applied to RDS's prod/staging
-- logical databases manually — documented in the README once we get there.

-- EP-2 fix: without this, docker-entrypoint's mysql client defaults its
-- connection charset to something other than utf8mb4 while loading this
-- file, so the multi-byte emoji literals below get corrupted on insert
-- (mojibake like "ðŸ§¥" instead of "🧥") even though the file itself is
-- correctly UTF-8 encoded on disk.
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(500) NOT NULL,
  price_cents INT NOT NULL,
  image_emoji VARCHAR(8) NOT NULL,
  stock INT NOT NULL DEFAULT 0
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS discount_codes (
  code VARCHAR(50) PRIMARY KEY,
  percent_off INT NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  subtotal_cents INT NOT NULL,
  discount_cents INT NOT NULL DEFAULT 0,
  total_cents INT NOT NULL,
  discount_code VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  unit_price_cents INT NOT NULL,
  quantity INT NOT NULL,
  line_total_cents INT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);

INSERT INTO products (name, description, price_cents, image_emoji, stock) VALUES
  ('Aurora Hoodie', 'Ultra-soft fleece hoodie in a gradient dye', 349900, '🧥', 40),
  ('Comet Sneakers', 'Lightweight running sneakers with reflective trim', 549900, '👟', 25),
  ('Nebula Backpack', 'Water-resistant backpack with laptop sleeve', 279900, '🎒', 30),
  ('Solstice Sunglasses', 'Polarized lenses, matte frame', 129900, '🕶️', 60),
  ('Prism Water Bottle', 'Insulated stainless steel, 750ml', 89900, '💧', 100),
  ('Lumen Desk Lamp', 'Adjustable LED lamp with warm/cool modes', 199900, '💡', 20)
ON DUPLICATE KEY UPDATE name = name;

INSERT INTO discount_codes (code, percent_off, active) VALUES
  ('WELCOME10', 10, 1),
  ('SUMMER20', 20, 1)
ON DUPLICATE KEY UPDATE percent_off = VALUES(percent_off);
