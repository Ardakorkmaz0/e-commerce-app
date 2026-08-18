"use client";

import { useState } from "react";
import { useActionState } from "react";

import { addToCart, type CartActionState } from "@/app/(store)/cart/actions";

import { QuantityStepper } from "./quantity-stepper";

import { findVariant, useVariantSelection } from "./variant-selection";

type VariantPickerProps = {
  productId: number;
  fallbackDescription: string;
};

const initialState: CartActionState = { message: "", success: false };

export function VariantPicker({
  productId,
  fallbackDescription,
}: VariantPickerProps) {
  const [state, formAction, pending] = useActionState(addToCart, initialState);
  const { groups, variants, selection, choose, variant } =
    useVariantSelection();

  const [quantity, setQuantity] = useState(1);

  /**
   * Whether picking this value still leads to a variant that exists.
   *
   * Everything else in the selection is held fixed, which is how a shop
   * greys out "US 12" once you have chosen a colour it is not made in.
   */
  function isAvailable(groupSlug: string, valueId: number): boolean {
    const candidate = { ...selection, [groupSlug]: valueId };
    const match = findVariant(variants, candidate);
    return match !== null && match.in_stock;
  }

  const description = variant?.description || fallbackDescription;
  const maxQuantity = Math.min(variant?.stock ?? 1, 20);

  return (
    <div className="variant-picker">
      {groups.map((group) => {
        const isColour = group.values.some((value) => value.swatch_color);

        return (
          <fieldset className="variant-group" key={group.slug}>
            <legend className="variant-group-title">{group.name}</legend>

            <div className={isColour ? "variant-swatches" : "variant-chips"}>
              {group.values.map((value) => {
                const selected = selection[group.slug] === value.id;
                const available = isAvailable(group.slug, value.id);

                return (
                  <button
                    key={value.id}
                    type="button"
                    className={[
                      isColour ? "variant-swatch" : "variant-chip",
                      selected ? "selected" : "",
                      available ? "" : "unavailable",
                    ]
                      .filter(Boolean)
                      .join(" ")}
                    style={
                      isColour
                        ? { backgroundColor: value.swatch_color || "#e2e8f0" }
                        : undefined
                    }
                    // Unavailable combinations stay clickable so the shopper
                    // can pivot to them; the button reports the state instead.
                    aria-pressed={selected}
                    title={available ? value.name : `${value.name} — unavailable`}
                    onClick={() => choose(group.slug, value.id)}
                  >
                    {isColour ? (
                      <span className="visually-hidden">{value.name}</span>
                    ) : (
                      value.name
                    )}
                  </button>
                );
              })}
            </div>
          </fieldset>
        );
      })}

      {description ? (
        <div className="variant-description">
          <h2 className="h6 mb-1">Description</h2>
          <p className="mb-0">{description}</p>
        </div>
      ) : null}

      <form action={formAction} className="variant-form">
        <input type="hidden" name="product_id" value={productId} />
        <input type="hidden" name="variant_id" value={variant?.id ?? ""} />

        <div className="d-flex align-items-center gap-3 mb-3">
          <span className="quantity-label">Quantity</span>
          <QuantityStepper
            name="quantity"
            value={quantity}
            onChange={setQuantity}
            max={Math.max(maxQuantity, 1)}
            disabled={!variant?.in_stock}
          />
        </div>

        <button
          className="btn signin-submit-button w-100 py-2"
          type="submit"
          disabled={pending || !variant || !variant.in_stock}
        >
          {!variant
            ? "Unavailable combination"
            : !variant.in_stock
              ? "Out of stock"
              : pending
                ? "Adding..."
                : "Add to cart"}
        </button>

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
    </div>
  );
}
