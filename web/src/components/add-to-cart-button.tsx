"use client";

import { useActionState } from "react";

import { addToCart, type CartActionState } from "@/app/(store)/cart/actions";

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
        <div className="d-flex align-items-center gap-2 mb-3">
          <label className="form-label mb-0" htmlFor="quantity">
            Quantity
          </label>
          <input
            id="quantity"
            name="quantity"
            type="number"
            className="form-control product-detail-quantity"
            defaultValue={1}
            min={1}
            max={Math.min(maxQuantity, 20)}
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
