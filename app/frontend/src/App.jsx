import { useEffect, useState } from "react";
import { fetchProducts, checkout } from "./api.js";

function formatPrice(cents) {
  return `₹${(cents / 100).toFixed(2)}`;
}

export default function App() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState([]); // [{...product, quantity}]
  const [discountCode, setDiscountCode] = useState("");
  const [order, setOrder] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchProducts()
      .then(setProducts)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  function addToCart(product) {
    setCart((prev) => {
      const existing = prev.find((i) => i.id === product.id);
      if (existing) {
        return prev.map((i) =>
          i.id === product.id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prev, { ...product, quantity: 1 }];
    });
  }

  function removeFromCart(productId) {
    setCart((prev) => prev.filter((i) => i.id !== productId));
  }

  const cartSubtotal = cart.reduce((sum, i) => sum + i.price_cents * i.quantity, 0);

  async function handleCheckout() {
    setError("");
    try {
      const result = await checkout(cart, discountCode);
      setOrder(result);
      setCart([]);
      setDiscountCode("");
    } catch (err) {
      setError(err.message);
    }
  }

  if (loading) return <div className="loading">Loading products…</div>;

  if (order) {
    return (
      <div className="app">
        <header className="header">
          <h1>🛍️ Ecom Platform</h1>
        </header>
        <div className="order-confirmation">
          <h2>✅ Order #{order.order_id} placed!</h2>
          <ul>
            {order.items.map((li) => (
              <li key={li.product_id}>
                {li.name} × {li.quantity} — {formatPrice(li.line_total_cents)}
              </li>
            ))}
          </ul>
          <p>Subtotal: {formatPrice(order.subtotal_cents)}</p>
          {order.discount_percent > 0 && (
            <p>
              Discount ({order.discount_percent}%): -{formatPrice(order.discount_cents)}
            </p>
          )}
          <p className="total">Total: {formatPrice(order.total_cents)}</p>
          <button onClick={() => setOrder(null)}>Continue shopping</button>
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <h1>🛍️ Ecom Platform</h1>
        <div className="cart-summary">
          🛒 {cart.reduce((n, i) => n + i.quantity, 0)} items — {formatPrice(cartSubtotal)}
        </div>
      </header>

      {error && <div className="error-banner">{error}</div>}

      <main className="layout">
        <section className="products-grid">
          {products.map((p) => (
            <div className="product-card" key={p.id}>
              <div className="product-emoji">{p.image_emoji}</div>
              <h3>{p.name}</h3>
              <p className="description">{p.description}</p>
              <p className="price">{formatPrice(p.price_cents)}</p>
              <p className="stock">{p.stock} in stock</p>
              <button onClick={() => addToCart(p)} disabled={p.stock < 1}>
                Add to cart
              </button>
            </div>
          ))}
        </section>

        <aside className="cart">
          <h2>Cart</h2>
          {cart.length === 0 && <p className="empty">Your cart is empty</p>}
          {cart.map((i) => (
            <div className="cart-item" key={i.id}>
              <span>
                {i.image_emoji} {i.name} × {i.quantity}
              </span>
              <span>{formatPrice(i.price_cents * i.quantity)}</span>
              <button className="remove" onClick={() => removeFromCart(i.id)}>
                ✕
              </button>
            </div>
          ))}

          {cart.length > 0 && (
            <>
              <input
                className="discount-input"
                placeholder="Discount code (e.g. WELCOME10)"
                value={discountCode}
                onChange={(e) => setDiscountCode(e.target.value)}
              />
              <p className="subtotal">Subtotal: {formatPrice(cartSubtotal)}</p>
              <button className="checkout-btn" onClick={handleCheckout}>
                Checkout
              </button>
            </>
          )}
        </aside>
      </main>
    </div>
  );
}
