"use client";

import { useState } from "react";

import type { ProductImage } from "@/lib/catalog";

import { useVariantSelection } from "./variant-selection";

type ProductGalleryProps = {
  /** The product's own picture, which leads the strip. */
  cover: string;
  alt: string;
  images: ProductImage[];
  /** False for products without options, which skip the variant context. */
  withVariants?: boolean;
};

/**
 * The picture panel: a column of thumbnails beside one large photo.
 *
 * The strip is built per selection — the chosen variant's own picture
 * first, then the product's, then the gallery, with variant-specific
 * photos filtered to the one on screen. Choosing a colour therefore
 * swaps the whole strip, not only the big image.
 */
export function ProductGallery(props: ProductGalleryProps) {
  return props.withVariants ? (
    <VariantAwareGallery {...props} />
  ) : (
    <Gallery photos={buildStrip(props.cover, props.images, null)} alt={props.alt} />
  );
}

/** Split out because hooks cannot be called conditionally. */
function VariantAwareGallery({ cover, alt, images }: ProductGalleryProps) {
  const { variant } = useVariantSelection();
  const photos = buildStrip(cover, images, variant?.id ?? null, variant?.image_url);

  return (
    // Remounts when the variant changes so the big photo is the new
    // variant's rather than whichever index was open before.
    <Gallery key={variant?.id ?? "none"} photos={photos} alt={alt} />
  );
}

function buildStrip(
  cover: string,
  images: ProductImage[],
  variantId: number | null,
  variantImage?: string,
): string[] {
  const strip: string[] = [];

  if (variantImage) strip.push(variantImage);
  if (cover) strip.push(cover);

  for (const image of images) {
    // Photos pinned to another variant belong to that one's strip.
    if (image.variant !== null && image.variant !== variantId) continue;
    if (image.url) strip.push(image.url);
  }

  // The same file can arrive as both the cover and a gallery row.
  return Array.from(new Set(strip));
}

function Gallery({ photos, alt }: { photos: string[]; alt: string }) {
  const [active, setActive] = useState(0);

  if (!photos.length) {
    return (
      <div className="product-detail-media">
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
      </div>
    );
  }

  const current = photos[Math.min(active, photos.length - 1)];

  return (
    <div className="product-gallery">
      {photos.length > 1 ? (
        <ul className="product-gallery-thumbs list-unstyled mb-0">
          {photos.map((photo, index) => (
            <li key={photo}>
              <button
                type="button"
                className={`product-gallery-thumb${
                  index === active ? " active" : ""
                }`}
                aria-label={`Photo ${index + 1} of ${photos.length}`}
                aria-current={index === active}
                // Hover previews it the way a shop does; the click is
                // still there for touch, where hover never fires.
                onMouseEnter={() => setActive(index)}
                onFocus={() => setActive(index)}
                onClick={() => setActive(index)}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={photo} alt="" loading="lazy" />
              </button>
            </li>
          ))}
        </ul>
      ) : null}

      <div className="product-detail-media">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={current} alt={alt} className="product-detail-image" />
      </div>
    </div>
  );
}
