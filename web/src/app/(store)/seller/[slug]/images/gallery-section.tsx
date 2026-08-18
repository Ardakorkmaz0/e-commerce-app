import type { SellerImage, SellerVariant } from "@/lib/seller";

import { GalleryCard } from "./gallery-card";
import { ImageForm } from "./image-form";

/** Mirrors MAX_GALLERY_PHOTOS in the API, which enforces it. */
const MAX_PHOTOS = 6;

type GallerySectionProps = {
  slug: string;
  /** The product's own picture, which always leads the strip. */
  cover: string;
  images: SellerImage[];
  variants: SellerVariant[];
};

/**
 * The extra photos, in the order a shopper will flip through them.
 *
 * The cover is shown first and greyed as a fixed card, because it comes
 * from the product form above rather than from this list — seeing it here
 * is what makes the running order make sense.
 */
export function GallerySection({
  slug,
  cover,
  images,
  variants,
}: GallerySectionProps) {
  const labelFor = (variantId: number | null) =>
    variantId === null
      ? "All variants"
      : (variants.find((variant) => variant.id === variantId)?.option_label ??
        "Removed variant");

  return (
    <section className="mt-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-2">
        <h2 className="section-title mb-0">Photos</h2>
        <span style={{ color: "var(--site-muted-text)" }}>
          {images.length
            ? `${images.length} of ${MAX_PHOTOS} extra photos`
            : "Cover only"}
        </span>
      </div>

      <p className="mb-3" style={{ color: "var(--site-muted-text)" }}>
        These appear as the thumbnail strip beside the product picture. Pin one
        to a variant and it only shows while that variant is chosen.
      </p>

      <ul className="list-unstyled gallery-grid mb-3">
        <li className="gallery-card gallery-card-cover">
          <div className="gallery-card-media">
            {cover ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={cover} alt="" />
            ) : (
              <span className="gallery-card-empty" />
            )}
          </div>
          <span className="gallery-card-tag">Cover · from the form above</span>
        </li>

        {images.map((image, index) => (
          <GalleryCard
            key={image.id}
            slug={slug}
            image={image}
            index={index}
            total={images.length}
            variants={variants}
            variantLabel={labelFor(image.variant)}
          />
        ))}
      </ul>

      {images.length >= MAX_PHOTOS ? (
        <p className="mb-0" style={{ color: "var(--site-muted-text)" }}>
          That is all {MAX_PHOTOS} extra photos. Delete one to add another, or
          edit any of them in place.
        </p>
      ) : (
        <div className="profile-card p-4">
          <h3 className="h6 mb-3">Add a photo</h3>
          <ImageForm slug={slug} variants={variants} />
        </div>
      )}
    </section>
  );
}
