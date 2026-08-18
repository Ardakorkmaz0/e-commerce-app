import type { Metadata } from "next";
import Link from "next/link";

import { CartQuantity } from "@/components/cart-quantity";
import { fetchCart } from "@/lib/cart";
import { formatPrice } from "@/lib/products";

import { clearCart, removeCartItem } from "./actions";

export const metadata: Metadata = {
  title: "Cart",
};

export default async function CartPage() {
  const cart = await fetchCart();

  if (!cart.items.length) {
    return (
      <main className="container py-5">
        <div className="cart-empty">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="56"
            height="56"
            fill="currentColor"
            viewBox="0 0 16 16"
            aria-hidden="true"
          >
            <path d="M0 1.5A.5.5 0 0 1 .5 1H2a.5.5 0 0 1 .485.379L2.89 3H14.5a.5.5 0 0 1 .49.598l-1 5a.5.5 0 0 1-.465.401l-9.397.472L4.415 11H13a.5.5 0 0 1 0 1H4a.5.5 0 0 1-.491-.408L2.01 3.607 1.61 2H.5a.5.5 0 0 1-.5-.5M5 14a1 1 0 1 1-2 0 1 1 0 0 1 2 0m7 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0" />
          </svg>
          <h1>Your cart is empty</h1>
          <p>Browse the catalog and add something you like.</p>
          <Link className="btn signin-submit-button" href="/products">
            Start shopping
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-3">
        <h1 className="section-title mb-0">
          Cart <span className="cart-count-note">({cart.item_count} items)</span>
        </h1>
        <form action={clearCart}>
          <button className="btn btn-sm btn-link text-danger p-0" type="submit">
            Clear cart
          </button>
        </form>
      </div>

      {cart.has_stock_issues ? (
        <div className="alert alert-warning" role="alert">
          Some items are no longer available in the quantity you chose. Adjust
          them before checking out.
        </div>
      ) : null}

      <div className="row g-4">
        <div className="col-12 col-lg-8">
          <ul className="list-unstyled cart-lines mb-0">
            {cart.items.map((item) => (
              <li className="cart-line" key={item.id}>
                <Link className="cart-line-media" href={`/products/${item.slug}`}>
                  {item.image_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={item.image_url} alt="" loading="lazy" />
                  ) : (
                    <span className="cart-line-placeholder" />
                  )}
                </Link>

                <div className="cart-line-body">
                  <Link className="cart-line-name" href={`/products/${item.slug}`}>
                    {item.name}
                  </Link>
                  {item.option_label ? (
                    <span className="cart-line-option">{item.option_label}</span>
                  ) : null}
                  <span className="cart-line-unit">
                    {formatPrice(item.unit_price)} each
                  </span>

                  {item.has_stock_issue ? (
                    <span className="cart-line-warning">
                      Only {item.available_stock} left
                    </span>
                  ) : null}

                  <div className="cart-line-controls">
                    <CartQuantity
                      itemId={item.id}
                      quantity={item.quantity}
                      max={Math.min(item.available_stock || 1, 20)}
                    />

                    <form action={removeCartItem}>
                      <input type="hidden" name="item_id" value={item.id} />
                      <button className="btn btn-sm btn-link text-danger" type="submit">
                        Remove
                      </button>
                    </form>
                  </div>
                </div>

                <div className="cart-line-total">{formatPrice(item.line_total)}</div>
              </li>
            ))}
          </ul>
        </div>

        <div className="col-12 col-lg-4">
          <aside className="cart-summary">
            <h2 className="h6 mb-3">Order summary</h2>

            <div className="cart-summary-row">
              <span>Items</span>
              <span>{cart.item_count}</span>
            </div>
            <div className="cart-summary-row">
              <span>Subtotal</span>
              <span>{formatPrice(cart.subtotal)}</span>
            </div>
            <div className="cart-summary-row muted">
              <span>Delivery</span>
              <span>Calculated at checkout</span>
            </div>

            <hr />

            <div className="cart-summary-row total">
              <span>Total</span>
              <span>{formatPrice(cart.subtotal)}</span>
            </div>

            {/* TODO: enable once orders and the fake payment flow exist. */}
            <button
              className="btn signin-submit-button w-100 py-2 mt-3"
              type="button"
              disabled
            >
              Checkout (coming soon)
            </button>

            <Link className="btn btn-link w-100 mt-1" href="/products">
              Continue shopping
            </Link>
          </aside>
        </div>
      </div>
    </main>
  );
}
