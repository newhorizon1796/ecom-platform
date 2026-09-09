const BASE = import.meta.env.VITE_API_URL || "/api";

export async function fetchProducts() {
  const res = await fetch(`${BASE}/products`);
  if (!res.ok) throw new Error("Failed to load products");
  return res.json();
}

export async function checkout(items, discountCode) {
  const res = await fetch(`${BASE}/checkout`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      items: items.map((i) => ({ product_id: i.id, quantity: i.quantity })),
      discount_code: discountCode || undefined,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Checkout failed");
  return data;
}
