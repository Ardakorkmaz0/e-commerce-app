"use client";

import { useActionState } from "react";

import type { SellerVariant } from "@/lib/seller";

import { updateVariant } from "./actions";
import { emptyVariantState, type VariantActionState } from "./variant-state";

type VariantRowProps = {
  slug: string;
  variant: SellerVariant;
  /** Shown as the placeholder in the price box. */
  productPrice: string;
};

/**
 * One line of the grid, edited where it sits.
 *
 * The three fields a seller actually changes — price, stock, visibility —
 * stay on the line. Picture and description are behind a disclosure so a
 * product with a dozen variants still reads as a list rather than a wall
 * of textareas.
 *
 * The option combination itself is not editable: changing it would quietly
 * turn one variant into another that shoppers may already have in a cart.
 * Delete and rebuild instead.
 */
export function VariantRow({ slug, variant, productPrice }: VariantRowProps) {
  const saveVariant = updateVariant.bind(null, slug, variant.id);
  const [state, formAction, pending] = useActionState<
    VariantActionState,
    FormData
  >(saveVariant, emptyVariantState);

  return (
    <form action={formAction} className="variant-line">
      <div className="variant-line-main">
        <div className="variant-line-media">
          {variant.image_display ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={variant.image_display} alt="" />
          ) : (
            <span className="variant-line-placeholder" />
          )}
        </div>

        <div className="variant-line-label">
          <strong>{variant.option_label}</strong>
          <span className="variant-row-sku">{variant.sku}</span>
        </div>

        <label className="variant-field">
          <span>Price</span>
          <input
            className="form-control"
            name="price"
            type="number"
            step="0.01"
            min="0.01"
            defaultValue={variant.price ?? ""}
            placeholder={productPrice}
          />
        </label>

        <label className="variant-field">
          <span>Stock</span>
          <input
            className="form-control"
            name="stock"
            type="number"
            min="0"
            defaultValue={variant.stock}
          />
        </label>

        <div className="form-check variant-line-visible">
          <input
            className="form-check-input"
            type="checkbox"
            name="is_active"
            id={`active-${variant.id}`}
            defaultChecked={variant.is_active}
          />
          <label className="form-check-label" htmlFor={`active-${variant.id}`}>
            Visible
          </label>
        </div>

        <button
          className="btn btn-sm signin-submit-button"
          type="submit"
          disabled={pending}
        >
          {pending ? "Saving..." : "Save"}
        </button>
      </div>

      <details className="variant-line-more">
        <summary>Picture and description</summary>

        <div className="variant-line-extra">
          <label className="variant-field">
            <span>Image URL</span>
            <input
              className="form-control"
              name="image_url"
              type="url"
              defaultValue={variant.image_url}
              placeholder="https://..."
            />
          </label>

          <label className="variant-field">
            <span>Upload image</span>
            <input
              className="form-control"
              name="image"
              type="file"
              accept="image/*"
            />
          </label>

          <label className="variant-field variant-field-full">
            <span>Description</span>
            <textarea
              className="form-control"
              name="description"
              rows={2}
              defaultValue={variant.description}
              placeholder="Empty = product description"
            />
          </label>
        </div>
      </details>

      {state.message ? (
        <p
          className={`add-to-cart-message ${state.success ? "ok" : "error"}`}
          role="status"
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}

      {Object.entries(state.errors).map(([field, messages]) => (
        <p className="add-to-cart-message error" key={field}>
          {messages.join(" ")}
        </p>
      ))}
    </form>
  );
}
