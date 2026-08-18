"use client";

import { useEffect, useRef, useState, useTransition } from "react";

import { updateCartItem } from "@/app/(store)/cart/actions";

import { QuantityStepper } from "./quantity-stepper";

type CartQuantityProps = {
  itemId: number;
  quantity: number;
  max: number;
};

/**
 * The cart line's stepper, which saves itself.
 *
 * The separate "Update" button meant a shopper could change the number,
 * walk to checkout and still be buying the old quantity. Tapping + now
 * commits on its own, after a short pause so that going 1 → 4 is one
 * request rather than three.
 */
export function CartQuantity({ itemId, quantity, max }: CartQuantityProps) {
  const [value, setValue] = useState(quantity);
  const [lastFromServer, setLastFromServer] = useState(quantity);
  const [saving, startSaving] = useTransition();
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // The server is the authority: when it comes back with a different
  // number (stock ran out), show that rather than the optimistic one.
  // Adjusted during render, which is React's answer to "derive state from
  // a prop" — an effect for this re-renders twice and trips the linter.
  if (quantity !== lastFromServer) {
    setLastFromServer(quantity);
    setValue(quantity);
  }

  useEffect(() => {
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  function change(next: number) {
    setValue(next);

    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      if (next === quantity) return;

      const payload = new FormData();
      payload.set("item_id", String(itemId));
      payload.set("quantity", String(next));
      startSaving(() => updateCartItem(payload));
    }, 400);
  }

  return (
    <div className="cart-qty">
      <QuantityStepper
        small
        value={value}
        onChange={change}
        max={Math.max(max, 1)}
      />
      {saving ? <span className="cart-qty-saving">Saving...</span> : null}
    </div>
  );
}
