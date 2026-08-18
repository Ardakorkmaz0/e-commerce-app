"use client";

import { useVariantSelection } from "./variant-selection";

/**
 * The big picture, swapped for the chosen variant.
 *
 * Falls back to the product's own picture whenever the variant has none,
 * so a seller only has to upload the ones that actually differ.
 */
export function VariantMedia({
  fallbackImage,
  alt,
}: {
  fallbackImage: string;
  alt: string;
}) {
  const { variant } = useVariantSelection();
  const image = variant?.image_url || fallbackImage;

  if (!image) {
    return (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="96"
        height="96"
        fill="currentColor"
        viewBox="0 0 16 16"
        aria-hidden="true"
      >
        <path d="M6.002 5.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0" />
        <path d="M2.002 1a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2zm12 1a1 1 0 0 1 1 1v6.5l-3.777-1.947a.5.5 0 0 0-.577.093l-3.71 3.71-2.66-1.772a.5.5 0 0 0-.63.062L1.002 12V3a1 1 0 0 1 1-1z" />
      </svg>
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={image} alt={alt} className="product-detail-image" />
  );
}
