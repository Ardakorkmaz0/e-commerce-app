"use client";

import Link from "next/link";
import { useActionState, useState } from "react";

import type { SellerFormState } from "./actions";
import { AttributePicker, type AttributeOption } from "./attribute-picker";

const initialState: SellerFormState = { errors: {}, message: "" };

type CategoryOption = { id: number; name: string };

type ProductFormProps = {
  action: (state: SellerFormState, formData: FormData) => Promise<SellerFormState>;
  categories: CategoryOption[];
  attributes: AttributeOption[];
  submitLabel: string;
  defaults?: {
    name: string;
    description: string;
    price: string;
    stock: number;
    category: number;
    image_url: string;
    is_active: boolean;
    attribute_values: number[];
  };
};

function FieldError({ errors }: { errors?: string[] }) {
  if (!errors?.length) {
    return null;
  }
  return (
    <div className="invalid-feedback d-block" role="alert">
      {errors.join(" ")}
    </div>
  );
}

export function ProductForm({
  action,
  categories,
  attributes,
  submitLabel,
  defaults,
}: ProductFormProps) {
  const [state, formAction, pending] = useActionState(action, initialState);

  // Tracked in state because the filter checkboxes below depend on it.
  const [categoryId, setCategoryId] = useState(
    defaults?.category ? String(defaults.category) : "",
  );

  return (
    <form action={formAction} className="profile-form">
      {state.message ? (
        <div className="alert alert-danger" role="alert" aria-live="polite">
          {state.message}
        </div>
      ) : null}

      <div className="mb-3">
        <label className="form-label" htmlFor="name">
          Product name
        </label>
        <input
          className="form-control"
          id="name"
          name="name"
          maxLength={200}
          required
          defaultValue={defaults?.name}
        />
        <FieldError errors={state.errors.name} />
      </div>

      <div className="row g-2 mb-3">
        <div className="col-sm-4">
          <label className="form-label" htmlFor="price">
            Price
          </label>
          <input
            className="form-control"
            id="price"
            name="price"
            type="number"
            step="0.01"
            min="0.01"
            required
            defaultValue={defaults?.price}
          />
          <FieldError errors={state.errors.price} />
        </div>

        <div className="col-sm-4">
          <label className="form-label" htmlFor="stock">
            Stock
          </label>
          <input
            className="form-control"
            id="stock"
            name="stock"
            type="number"
            min="0"
            required
            defaultValue={defaults?.stock ?? 0}
          />
          <FieldError errors={state.errors.stock} />
        </div>

        <div className="col-sm-4">
          <label className="form-label" htmlFor="category">
            Category
          </label>
          <select
            className="form-select"
            id="category"
            name="category"
            required
            value={categoryId}
            onChange={(event) => setCategoryId(event.target.value)}
          >
            <option value="" disabled>
              Choose...
            </option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
          <FieldError errors={state.errors.category} />
        </div>
      </div>

      {/* Filter tags — the options follow the category chosen above */}
      <div className="mb-3">
        <label className="form-label">Filters</label>
        <div className="attribute-box p-3">
          <AttributePicker
            attributes={attributes}
            categoryId={categoryId}
            selectedValueIds={defaults?.attribute_values ?? []}
          />
        </div>
        <FieldError errors={state.errors.attribute_values} />
      </div>

      <div className="mb-3">
        <label className="form-label" htmlFor="description">
          Description
        </label>
        <textarea
          className="form-control"
          id="description"
          name="description"
          rows={4}
          defaultValue={defaults?.description}
        />
        <FieldError errors={state.errors.description} />
      </div>

      <div className="mb-3">
        <label className="form-label" htmlFor="image">
          Image file
        </label>
        <input
          className="form-control"
          id="image"
          name="image"
          type="file"
          accept="image/*"
        />
        <div className="form-text">
          Upload a file or paste a link below. The uploaded file wins.
        </div>
        <FieldError errors={state.errors.image} />
      </div>

      <div className="mb-3">
        <label className="form-label" htmlFor="image_url">
          Image link
        </label>
        <input
          className="form-control"
          id="image_url"
          name="image_url"
          type="url"
          placeholder="https://..."
          defaultValue={defaults?.image_url}
        />
        <FieldError errors={state.errors.image_url} />
      </div>

      <div className="form-check mb-4">
        <input
          className="form-check-input"
          type="checkbox"
          id="is_active"
          name="is_active"
          defaultChecked={defaults?.is_active ?? true}
        />
        <label className="form-check-label" htmlFor="is_active">
          Visible in the store
        </label>
      </div>

      <div className="d-flex gap-2">
        <Link className="btn btn-outline-secondary" href="/seller">
          Cancel
        </Link>
        <button
          className="btn signin-submit-button flex-grow-1"
          type="submit"
          disabled={pending}
        >
          {pending ? "Saving..." : submitLabel}
        </button>
      </div>
    </form>
  );
}
