import type { AttributeOption } from "@/lib/products";
import { formatPrice } from "@/lib/products";
import type { SellerVariant } from "@/lib/seller";

import { deleteVariant } from "./actions";
import { VariantGenerator } from "./variant-generator";
import { VariantRow } from "./variant-row";

type VariantSectionProps = {
  slug: string;
  productName: string;
  productPrice: string;
  productStock: number;
  /** Already narrowed to the product's category by the page. */
  attributes: AttributeOption[];
  variants: SellerVariant[];
};

/**
 * The variant grid, rendered underneath the product form on the same page.
 *
 * A server component: the rows and the generator are the only parts that
 * need to be interactive, so only they cross to the client.
 */
export function VariantSection({
  slug,
  productName,
  productPrice,
  productStock,
  attributes,
  variants,
}: VariantSectionProps) {
  const totalStock = variants.reduce((sum, variant) => sum + variant.stock, 0);

  return (
    <section className="mt-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-2">
        <h2 className="section-title mb-0">Variants</h2>
        <span style={{ color: "var(--site-muted-text)" }}>
          {variants.length
            ? `${variants.length} variant${variants.length === 1 ? "" : "s"} · ${totalStock} in stock`
            : "None yet"}
        </span>
      </div>

      <p className="mb-3" style={{ color: "var(--site-muted-text)" }}>
        A product with variants is bought as one of them, so the variant&apos;s
        price, stock and picture take over. Leave a price or description empty
        to keep using {productName}&apos;s.
      </p>

      <div className="profile-card p-4 mb-3">
        <h3 className="h6 mb-3">Build combinations</h3>
        <VariantGenerator slug={slug} attributes={attributes} />
      </div>

      {variants.length ? (
        <ul className="list-unstyled variant-lines mb-0">
          {variants.map((variant) => (
            <li className="variant-line-item" key={variant.id}>
              <VariantRow
                slug={slug}
                variant={variant}
                productPrice={productPrice}
              />

              {/* Its own form: a form cannot be nested inside another. */}
              <form action={deleteVariant} className="variant-line-delete">
                <input type="hidden" name="slug" value={slug} />
                <input type="hidden" name="variant_id" value={variant.id} />
                <button className="btn btn-sm btn-link text-danger" type="submit">
                  Delete
                </button>
              </form>
            </li>
          ))}
        </ul>
      ) : (
        <p className="mb-0" style={{ color: "var(--site-muted-text)" }}>
          This product is sold on its own at {formatPrice(productPrice)} with{" "}
          {productStock} in stock.
        </p>
      )}
    </section>
  );
}
