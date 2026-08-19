"use client";

import Link from "next/link";
import { useActionState, useId, useState } from "react";

import type { Address } from "@/lib/addresses";
import type { Cart } from "@/lib/cart";
import type { PaymentMethod } from "@/lib/payments";
import { formatPrice } from "@/lib/catalog";

import { placeOrder } from "./actions";
import { emptyCheckoutState, type CheckoutState } from "./checkout-state";
import { OrderPreview } from "./order-preview";

type CheckoutFormProps = {
  cart: Cart;
  addresses: Address[];
  cards: PaymentMethod[];
};

/**
 * The whole checkout, on one page.
 *
 * Amazon's shape: numbered sections down the left, a summary that follows
 * the scroll on the right. Nothing here writes an order — the last button
 * shows what the order *would* be, and the cart is left alone.
 */
export function CheckoutForm({ cart, addresses, cards }: CheckoutFormProps) {
  const usableCards = cards.filter((card) => !card.is_expired);

  const [addressId, setAddressId] = useState<number | null>(
    () => (addresses.find((a) => a.is_default) ?? addresses[0])?.id ?? null,
  );
  const [cardId, setCardId] = useState<number | null>(
    () =>
      (usableCards.find((c) => c.is_default) ?? usableCards[0])?.id ?? null,
  );
  const [preview, setPreview] = useState(false);
  const [state, formAction, pending] = useActionState<CheckoutState, FormData>(
    placeOrder,
    emptyCheckoutState,
  );

  // Generated once per mount, so a refresh of the confirm step sends the
  // same key and the API returns the order already placed.
  const idempotencyKey = useId();

  const address = addresses.find((item) => item.id === addressId) ?? null;
  const card = usableCards.find((item) => item.id === cardId) ?? null;

  const ready = Boolean(address && card && !cart.has_stock_issues);
  const freeShipping = Number(cart.shipping) === 0;
  const remaining = Number(cart.free_shipping_remaining);

  return (
    <div className="row g-4 align-items-start">
      <div className="col-12 col-lg-8">
        <ol className="list-unstyled checkout-sections mb-0">
          {/* 1 — where it goes */}
          <li className="checkout-section">
            <h2 className="checkout-section-title">
              <span className="checkout-step">1</span> Delivery address
            </h2>

            {addresses.length ? (
              <div className="checkout-choices">
                {addresses.map((item) => (
                  <label
                    className={`checkout-choice${
                      item.id === addressId ? " selected" : ""
                    }`}
                    key={item.id}
                  >
                    <input
                      type="radio"
                      name="address"
                      className="form-check-input"
                      checked={item.id === addressId}
                      onChange={() => setAddressId(item.id)}
                    />
                    <span>
                      <strong>{item.label}</strong>
                      {item.is_default ? (
                        <span className="checkout-default">Default</span>
                      ) : null}
                      <span className="checkout-choice-body">
                        {item.recipient_name} · {item.phone_number}
                        <br />
                        {item.address_line_1}
                        {item.address_line_2 ? `, ${item.address_line_2}` : ""}
                        <br />
                        {item.district}, {item.city} {item.postal_code}
                      </span>
                    </span>
                  </label>
                ))}
              </div>
            ) : (
              <p className="checkout-empty">
                You have no saved addresses.{" "}
                <Link href="/profile/addresses/new">Add one</Link> to continue.
              </p>
            )}

            <Link className="btn btn-link p-0" href="/profile/addresses">
              Manage addresses
            </Link>
          </li>

          {/* 2 — how it is paid */}
          <li className="checkout-section">
            <h2 className="checkout-section-title">
              <span className="checkout-step">2</span> Payment method
            </h2>

            {usableCards.length ? (
              <>
                <div className="checkout-choices">
                  {usableCards.map((item) => (
                    <label
                      className={`checkout-choice${
                        item.id === cardId ? " selected" : ""
                      }`}
                      key={item.id}
                    >
                      <input
                        type="radio"
                        name="card"
                        className="form-check-input"
                        checked={item.id === cardId}
                        onChange={() => setCardId(item.id)}
                      />
                      <span>
                        <strong>
                          {item.brand_display} ···· {item.last4}
                        </strong>
                        {item.is_default ? (
                          <span className="checkout-default">Default</span>
                        ) : null}
                        <span className="checkout-choice-body">
                          {item.holder_name} · expires{" "}
                          {String(item.exp_month).padStart(2, "0")}/
                          {item.exp_year}
                        </span>
                      </span>
                    </label>
                  ))}
                </div>

                {/* One option, but naming it is what a shopper looks for. */}
                <div className="checkout-instalment">
                  <span className="checkout-instalment-label">
                    Single payment
                  </span>
                  <span>{formatPrice(cart.total)} charged at once</span>
                </div>
              </>
            ) : (
              <p className="checkout-empty">
                {cards.length
                  ? "Every saved card has expired. "
                  : "You have no saved cards. "}
                <Link href="/profile/payment-methods">Add a card</Link> to
                continue.
              </p>
            )}

            <Link className="btn btn-link p-0" href="/profile/payment-methods">
              Manage cards
            </Link>
          </li>

          {/* 3 — what is in it */}
          <li className="checkout-section">
            <h2 className="checkout-section-title">
              <span className="checkout-step">3</span> Items ({cart.item_count})
            </h2>

            <ul className="list-unstyled checkout-items mb-0">
              {cart.items.map((item) => (
                <li className="checkout-item" key={item.id}>
                  <div className="checkout-item-media">
                    {item.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={item.image_url} alt="" loading="lazy" />
                    ) : (
                      <span className="checkout-item-placeholder" />
                    )}
                  </div>

                  <div className="checkout-item-body">
                    <Link
                      className="checkout-item-name"
                      href={`/products/${item.slug}`}
                    >
                      {item.name}
                    </Link>
                    {item.option_label ? (
                      <span className="cart-line-option">
                        {item.option_label}
                      </span>
                    ) : null}
                    <span className="checkout-item-meta">
                      {formatPrice(item.unit_price)} × {item.quantity}
                    </span>
                  </div>

                  <div className="cart-line-total">
                    {formatPrice(item.line_total)}
                  </div>
                </li>
              ))}
            </ul>

            <Link className="btn btn-link p-0 mt-2" href="/cart">
              Change quantities
            </Link>
          </li>
        </ol>
      </div>

      {/* Summary, following the scroll */}
      <div className="col-12 col-lg-4">
        <aside className="cart-summary checkout-summary">
          <h2 className="h6 mb-3">Order summary</h2>

          <div className="cart-summary-row">
            <span>Items ({cart.item_count})</span>
            <span>{formatPrice(cart.subtotal)}</span>
          </div>

          <div className="cart-summary-row">
            <span>Delivery</span>
            <span className={freeShipping ? "checkout-free" : undefined}>
              {freeShipping ? "Free" : formatPrice(cart.shipping)}
            </span>
          </div>

          {remaining > 0 ? (
            <p className="checkout-nudge mb-0">
              Spend {formatPrice(cart.free_shipping_remaining)} more for free
              delivery.
            </p>
          ) : null}

          <hr />

          <div className="cart-summary-row total">
            <span>Total</span>
            <span>{formatPrice(cart.total)}</span>
          </div>

          <button
            className="btn signin-submit-button w-100 py-2 mt-3"
            type="button"
            disabled={!ready || pending}
            onClick={() => setPreview(true)}
          >
            {pending ? "Placing..." : "Place your order"}
          </button>

          {!ready ? (
            <p className="checkout-nudge mb-0 mt-2">
              {cart.has_stock_issues
                ? "Fix the stock warnings above first."
                : !address
                  ? "Choose a delivery address first."
                  : "Choose a payment method first."}
            </p>
          ) : (
            <p className="checkout-nudge mb-0 mt-2">
              You will see the whole order before anything is charged.
            </p>
          )}

          {state.message ? (
            <p
              className="add-to-cart-message error"
              role="status"
              aria-live="polite"
            >
              {state.message}
            </p>
          ) : null}
        </aside>
      </div>

      {preview && address && card ? (
        <OrderPreview
          cart={cart}
          address={address}
          card={card}
          addressId={address.id}
          cardId={card.id}
          idempotencyKey={idempotencyKey}
          formAction={formAction}
          pending={pending}
          onClose={() => setPreview(false)}
        />
      ) : null}
    </div>
  );
}
