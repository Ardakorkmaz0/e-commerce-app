"use client";

import { useEffect, useRef } from "react";

import type { Address } from "@/lib/addresses";
import type { Cart } from "@/lib/cart";
import type { PaymentMethod } from "@/lib/payments";
import { formatPrice } from "@/lib/catalog";

type OrderPreviewProps = {
  cart: Cart;
  address: Address;
  card: PaymentMethod;
  addressId: number;
  cardId: number;
  /** Same value for the life of the page, so a refresh cannot double-order. */
  idempotencyKey: string;
  formAction: (payload: FormData) => void;
  pending: boolean;
  onClose: () => void;
};

/**
 * The last look before the card is charged.
 *
 * Amazon shows the whole order once more rather than letting a single
 * click on a summary spend money; this is that step. Confirming here is
 * what actually places it.
 */
export function OrderPreview({
  cart,
  address,
  card,
  addressId,
  cardId,
  idempotencyKey,
  formAction,
  pending,
  onClose,
}: OrderPreviewProps) {
  const closeButton = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    closeButton.current?.focus();

    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      className="order-preview-backdrop"
      // A click on the sheet itself must not close it.
      onClick={onClose}
      role="presentation"
    >
      <div
        className="order-preview"
        role="dialog"
        aria-modal="true"
        aria-labelledby="order-preview-title"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="order-preview-head">
          <h2 className="h5 mb-0" id="order-preview-title">
            Confirm your order
          </h2>
          <button
            className="order-preview-close"
            type="button"
            ref={closeButton}
            aria-label="Close"
            onClick={onClose}
          >
            <svg width="18" height="18" viewBox="0 0 16 16" aria-hidden="true">
              <path
                d="M2.65 2.65a.75.75 0 0 1 1.06 0L8 6.94l4.29-4.29a.75.75 0 1 1 1.06 1.06L9.06 8l4.29 4.29a.75.75 0 1 1-1.06 1.06L8 9.06l-4.29 4.29a.75.75 0 0 1-1.06-1.06L6.94 8 2.65 3.71a.75.75 0 0 1 0-1.06"
                fill="currentColor"
              />
            </svg>
          </button>
        </div>

        <p className="order-preview-note">
          {formatPrice(cart.total)} will be charged to your{" "}
          {card.brand_display} ending {card.last4} as a single payment.
        </p>

        <dl className="order-preview-grid">
          <div>
            <dt>Ships to</dt>
            <dd>
              {address.recipient_name}
              <br />
              {address.address_line_1}
              {address.address_line_2 ? `, ${address.address_line_2}` : ""}
              <br />
              {address.district}, {address.city} {address.postal_code}
            </dd>
          </div>

          <div>
            <dt>Paid with</dt>
            <dd>
              {card.brand_display} ···· {card.last4}
              <br />
              Single payment
            </dd>
          </div>
        </dl>

        <ul className="list-unstyled order-preview-items">
          {cart.items.map((item) => (
            <li key={item.id}>
              <span>
                {item.name}
                {item.option_label ? ` — ${item.option_label}` : ""} ×{" "}
                {item.quantity}
              </span>
              <span>{formatPrice(item.line_total)}</span>
            </li>
          ))}
        </ul>

        <div className="cart-summary-row">
          <span>Items</span>
          <span>{formatPrice(cart.subtotal)}</span>
        </div>
        <div className="cart-summary-row">
          <span>Delivery</span>
          <span>
            {Number(cart.shipping) === 0 ? "Free" : formatPrice(cart.shipping)}
          </span>
        </div>
        <div className="cart-summary-row total">
          <span>Total</span>
          <span>{formatPrice(cart.total)}</span>
        </div>

        <form action={formAction} className="mt-3">
          <input type="hidden" name="address_id" value={addressId} />
          <input type="hidden" name="payment_method_id" value={cardId} />
          <input
            type="hidden"
            name="idempotency_key"
            value={idempotencyKey}
          />

          <button
            className="btn signin-submit-button w-100 py-2"
            type="submit"
            disabled={pending}
          >
            {pending ? "Placing your order..." : "Confirm and pay"}
          </button>
        </form>

        <button
          className="btn btn-link w-100 mt-1"
          type="button"
          disabled={pending}
          onClick={onClose}
        >
          Go back
        </button>
      </div>
    </div>
  );
}
