"use client";

import { useActionState, useState } from "react";

import type { SellerImage, SellerVariant } from "@/lib/seller";

import {
  emptyVariantState,
  type VariantActionState,
} from "../variants/variant-state";
import { deleteImage, moveImage, updateImage } from "./actions";

type GalleryCardProps = {
  slug: string;
  image: SellerImage;
  index: number;
  total: number;
  variants: SellerVariant[];
  variantLabel: string;
};

/**
 * One photo, edited where it sits.
 *
 * The picture, its caption and which variant it belongs to are all
 * changed from this card — a photo pasted into the wrong slot used to
 * mean deleting it and adding it again in the right place.
 */
export function GalleryCard({
  slug,
  image,
  index,
  total,
  variants,
  variantLabel,
}: GalleryCardProps) {
  const [editing, setEditing] = useState(false);
  const saveImage = updateImage.bind(null, slug, image.id);
  const [state, formAction, pending] = useActionState<
    VariantActionState,
    FormData
  >(saveImage, emptyVariantState);

  return (
    <li className="gallery-card">
      <div className="gallery-card-media">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={image.url} alt={image.alt} />
      </div>

      <span className="gallery-card-tag" title={image.alt || variantLabel}>
        {variantLabel}
      </span>

      <div className="gallery-card-actions">
        <MoveButton
          slug={slug}
          imageId={image.id}
          position={index - 1}
          disabled={index === 0}
          label="Move earlier"
          icon={<ChevronLeft />}
        />

        <button
          type="button"
          className="gallery-icon-button"
          aria-label={editing ? "Close editor" : "Edit photo"}
          aria-expanded={editing}
          onClick={() => setEditing((open) => !open)}
        >
          <Pencil />
        </button>

        <form action={deleteImage}>
          <input type="hidden" name="slug" value={slug} />
          <input type="hidden" name="image_id" value={image.id} />
          <button
            className="gallery-icon-button danger"
            type="submit"
            aria-label="Delete photo"
          >
            <Trash />
          </button>
        </form>

        <MoveButton
          slug={slug}
          imageId={image.id}
          position={index + 1}
          disabled={index === total - 1}
          label="Move later"
          icon={<ChevronRight />}
        />
      </div>

      {editing ? (
        <form action={formAction} className="gallery-card-edit">
          <label className="variant-field">
            <span>Image URL</span>
            <input
              className="form-control form-control-sm"
              name="image_url"
              type="url"
              defaultValue={image.url}
            />
          </label>

          <label className="variant-field">
            <span>Replace with a file</span>
            <input
              className="form-control form-control-sm"
              name="image"
              type="file"
              accept="image/*"
            />
          </label>

          <label className="variant-field">
            <span>Alt text</span>
            <input
              className="form-control form-control-sm"
              name="alt"
              type="text"
              maxLength={140}
              defaultValue={image.alt}
            />
          </label>

          {variants.length ? (
            <label className="variant-field">
              <span>Show for</span>
              <select
                className="form-select form-select-sm"
                name="variant"
                defaultValue={image.variant ?? ""}
              >
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
            className="btn btn-sm signin-submit-button"
            type="submit"
            disabled={pending}
          >
            {pending ? "Saving..." : "Save"}
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

          {Object.entries(state.errors).map(([field, messages]) => (
            <p className="add-to-cart-message error" key={field}>
              {messages.join(" ")}
            </p>
          ))}
        </form>
      ) : null}
    </li>
  );
}

/** Its own form, because a form cannot be nested inside another. */
function MoveButton({
  slug,
  imageId,
  position,
  disabled,
  label,
  icon,
}: {
  slug: string;
  imageId: number;
  position: number;
  disabled: boolean;
  label: string;
  icon: React.ReactNode;
}) {
  return (
    <form action={moveImage}>
      <input type="hidden" name="slug" value={slug} />
      <input type="hidden" name="image_id" value={imageId} />
      <input type="hidden" name="position" value={position} />
      <button
        className="gallery-icon-button"
        type="submit"
        disabled={disabled}
        aria-label={label}
      >
        {icon}
      </button>
    </form>
  );
}

function ChevronLeft() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M10.35 3.15a.75.75 0 0 1 0 1.06L6.56 8l3.79 3.79a.75.75 0 1 1-1.06 1.06L4.94 8.53a.75.75 0 0 1 0-1.06l4.35-4.32a.75.75 0 0 1 1.06 0"
        fill="currentColor"
      />
    </svg>
  );
}

function ChevronRight() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M5.65 3.15a.75.75 0 0 0 0 1.06L9.44 8l-3.79 3.79a.75.75 0 1 0 1.06 1.06l4.35-4.32a.75.75 0 0 0 0-1.06L6.71 3.15a.75.75 0 0 0-1.06 0"
        fill="currentColor"
      />
    </svg>
  );
}

function Pencil() {
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M12.15 1.35a1.2 1.2 0 0 1 1.7 0l.8.8a1.2 1.2 0 0 1 0 1.7l-.9.9-2.5-2.5zM10.4 3.1l2.5 2.5-7 7-3.1.6.6-3.1z"
        fill="currentColor"
      />
    </svg>
  );
}

function Trash() {
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M6.5 1a.5.5 0 0 0-.5.5V2H3.25a.75.75 0 0 0 0 1.5h9.5a.75.75 0 0 0 0-1.5H10v-.5a.5.5 0 0 0-.5-.5zM4.4 4.75h7.2l-.55 8.4A1.4 1.4 0 0 1 9.66 14.5H6.34a1.4 1.4 0 0 1-1.39-1.35z"
        fill="currentColor"
      />
    </svg>
  );
}
