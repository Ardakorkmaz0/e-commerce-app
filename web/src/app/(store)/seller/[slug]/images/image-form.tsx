"use client";

import { useActionState } from "react";

import type { SellerVariant } from "@/lib/seller";

import { emptyVariantState, type VariantActionState } from "../variants/variant-state";
import { addImage } from "./actions";

type ImageFormProps = {
  slug: string;
  /** Lets a photo be pinned to one combination, e.g. the black shoe. */
  variants: SellerVariant[];
};

export function ImageForm({ slug, variants }: ImageFormProps) {
  const addToProduct = addImage.bind(null, slug);
  const [state, formAction, pending] = useActionState<
    VariantActionState,
    FormData
  >(addToProduct, emptyVariantState);

  return (
    <form action={formAction} className="gallery-form">
      <label className="variant-field">
        <span>Image URL</span>
        <input
          className="form-control"
          name="image_url"
          type="url"
          placeholder="https://..."
        />
      </label>

      <label className="variant-field">
        <span>or upload</span>
        <input className="form-control" name="image" type="file" accept="image/*" />
      </label>

      <label className="variant-field">
        <span>Alt text</span>
        <input
          className="form-control"
          name="alt"
          type="text"
          maxLength={140}
          placeholder="What the photo shows"
        />
      </label>

      {variants.length ? (
        <label className="variant-field">
          <span>Show for</span>
          <select className="form-select" name="variant" defaultValue="">
            <option value="">Every variant</option>
            {variants.map((variant) => (
              <option key={variant.id} value={variant.id}>
                {variant.option_label}
              </option>
            ))}
          </select>
        </label>
      ) : null}

      <button
        className="btn signin-submit-button gallery-form-submit"
        type="submit"
        disabled={pending}
      >
        {pending ? "Adding..." : "Add photo"}
      </button>

      {state.message ? (
        <p
          className={`add-to-cart-message ${state.success ? "ok" : "error"} gallery-form-message`}
          role="status"
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}

      {Object.entries(state.errors).map(([field, messages]) => (
        <p className="add-to-cart-message error gallery-form-message" key={field}>
          {messages.join(" ")}
        </p>
      ))}
    </form>
  );
}
