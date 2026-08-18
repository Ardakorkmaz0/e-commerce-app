"use client";

import { useActionState, useState } from "react";

import { addToCart, type CartActionState } from "@/app/(store)/cart/actions";

import { QuantityStepper } from "./quantity-stepper";

const initialState: CartActionState = { message: "", success: false };

type AddToCartButtonProps = {
  productId: number;
  inStock: boolean;
  maxQuantity: number;
  /** The detail page offers a quantity; a grid card just adds one. */
  withQuantity?: boolean;
  label?: string;
  className?: string;
};

export function AddToCartButton({
  productId,
  inStock,
  maxQuantity,
  withQuantity = false,
  label = "Add to cart",
  className = "btn signin-submit-button w-100 py-2",
}: AddToCartButtonProps) {
  const [state, formAction, pending] = useActionState(addToCart, initialState);
  const [quantity, setQuantity] = useState(1);

  if (!inStock) {
    return (
      <button className={className} type="button" disabled>
        Out of stock
      </button>
    );
  }

  return (
    <form action={formAction} className="add-to-cart-form">
      <input type="hidden" name="product_id" value={productId} />

      {withQuantity ? (
        <div className="d-flex align-items-center gap-3 mb-3">
          <span className="quantity-label">Quantity</span>
          <QuantityStepper
            name="quantity"
            value={quantity}
            onChange={setQuantity}
            max={Math.max(Math.min(maxQuantity, 20), 1)}
          />
        </div>
      ) : (
        <input type="hidden" name="quantity" value={1} />
      )}

      <button className={className} type="submit" disabled={pending}>
        {pending ? "Adding..." : label}
      </button>

      {/* The API is the authority on stock, so its message is shown as is. */}
      {state.message ? (
        <p
          className={`add-to-cart-message ${state.success ? "ok" : "error"}`}
          role="status"
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}
    </form>
  );
}
