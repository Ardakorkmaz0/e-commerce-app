"use client";

import { useMemo, useState } from "react";

import { addToCart, type CartActionState } from "@/app/(store)/cart/actions";
import type { OptionGroup, ProductVariant } from "@/lib/catalog";
import { formatPrice } from "@/lib/catalog";
import { useActionState } from "react";

type VariantPickerProps = {
  productId: number;
  groups: OptionGroup[];
  variants: ProductVariant[];
  fallbackImage: string;
  fallbackDescription: string;
};

const initialState: CartActionState = { message: "", success: false };

/** A selection matches a variant when the two sets of value ids are equal. */
function findVariant(
  variants: ProductVariant[],
  selection: Record<string, number>,
): ProductVariant | null {
  const chosen = Object.values(selection).sort((a, b) => a - b);
  return (
    variants.find(
      (variant) =>
        variant.option_value_ids.length === chosen.length &&
        variant.option_value_ids.every((id, index) => id === chosen[index]),
    ) ?? null
  );
}

export function VariantPicker({
  productId,
  groups,
  variants,
  fallbackImage,
  fallbackDescription,
}: VariantPickerProps) {
  const [state, formAction, pending] = useActionState(addToCart, initialState);

  // Start on the first combination that can actually be bought, so the page
  // opens showing a real price rather than an empty picker.
  const [selection, setSelection] = useState<Record<string, number>>(() => {
    const first = variants.find((variant) => variant.in_stock) ?? variants[0];
    if (!first) return {};

    const initial: Record<string, number> = {};
    for (const group of groups) {
      const match = group.values.find((value) =>
        first.option_value_ids.includes(value.id),
      );
      if (match) initial[group.slug] = match.id;
    }
    return initial;
  });

  const [quantity, setQuantity] = useState(1);

  const variant = useMemo(
    () => findVariant(variants, selection),
    [variants, selection],
  );

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

  const image = variant?.image_url || fallbackImage;
  const description = variant?.description || fallbackDescription;
  const maxQuantity = Math.min(variant?.stock ?? 1, 20);

  return (
    <div className="variant-picker">
      {image ? (
        <div className="variant-preview">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={image} alt="" />
        </div>
      ) : null}

      <div className="variant-price">
        {variant ? formatPrice(variant.price) : "Choose an option"}
      </div>

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
                    onClick={() =>
                      setSelection((current) => ({
                        ...current,
                        [group.slug]: value.id,
                      }))
                    }
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

        <div className="d-flex align-items-center gap-2 mb-3">
          <label className="form-label mb-0" htmlFor="quantity">
            Quantity
          </label>
          <input
            id="quantity"
            name="quantity"
            type="number"
            className="form-control product-detail-quantity"
            min={1}
            max={Math.max(maxQuantity, 1)}
            value={quantity}
            onChange={(event) => setQuantity(Number(event.target.value) || 1)}
            disabled={!variant?.in_stock}
          />
          {variant?.in_stock ? (
            <span className="variant-stock">{variant.stock} in stock</span>
          ) : null}
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
