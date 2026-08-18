import Link from "next/link";
import { notFound } from "next/navigation";

import { AddToCartButton } from "@/components/add-to-cart-button";
import { ProductCard } from "@/components/product-card";
import { VariantMedia } from "@/components/variant-media";
import { VariantPicker } from "@/components/variant-picker";
import { VariantPrice } from "@/components/variant-price";
import { VariantSelectionProvider } from "@/components/variant-selection";
import { SellerRatingForm } from "@/components/seller-rating-form";
import { VerifiedSellerBadge } from "@/components/verified-seller-badge";
import { getCurrentUser } from "@/lib/auth";
import { fetchProduct, fetchProducts, formatPrice } from "@/lib/products";
import { fetchSellerRating } from "@/lib/seller-ratings";

type ProductPageProps = {
  params: Promise<{ slug: string }>;
};

// The tab title becomes the product name. Next.js dedupes this fetch with
// the one in the page below, so the API is only called once.
export async function generateMetadata({ params }: ProductPageProps) {
  const { slug } = await params;
  const product = await fetchProduct(slug);
  return { title: product?.name ?? "Product" };
}

export default async function ProductPage({ params }: ProductPageProps) {
  const { slug } = await params;
  const product = await fetchProduct(slug);

  if (!product) {
    notFound();
  }

  const [categoryProducts, user, ownSellerRating] = await Promise.all([
    fetchProducts({ category: product.category_slug }),
    getCurrentUser(),
    product.seller
      ? fetchSellerRating(product.seller.id)
      : Promise.resolve(null),
  ]);

  // Other products from the same category, current one removed.
  const related = categoryProducts
    .filter((item) => item.id !== product.id)
    .slice(0, 4);

  // Once a product has variants they carry the price and the stock, so the
  // product's own columns stop being the truth.
  const hasVariants = Boolean(product.has_variants && product.variants?.length);
  const stock = hasVariants ? (product.total_stock ?? 0) : product.stock;

  const sellerRating = product.seller
    ? (ownSellerRating?.rating ?? product.seller.rating)
    : null;
  const sellerRatingCount = product.seller
    ? (ownSellerRating?.rating_count ?? product.seller.rating_count)
    : 0;

  return (
    <main className="container py-4">
      <nav aria-label="Breadcrumb" className="product-breadcrumb mb-3">
        <Link href="/products">Products</Link>
        <span aria-hidden="true"> / </span>
        <Link href={`/products?category=${product.category_slug}`}>
          {product.category}
        </Link>
      </nav>

      <VariantSelectionProvider
        groups={product.option_groups ?? []}
        variants={product.variants ?? []}
      >
        <div className="row g-4 align-items-start">
          {/* Image */}
          <div className="col-12 col-lg-6">
            <div className="product-detail-media">
              {hasVariants ? (
                <VariantMedia
                  fallbackImage={product.image_url}
                  alt={product.name}
                />
              ) : product.image_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={product.image_url}
                  alt={product.name}
                  className="product-detail-image"
                />
              ) : (
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
              )}
            </div>
          </div>

          {/* Details */}
          <div className="col-12 col-lg-6">
            <div className="product-detail-panel p-4">
              <span className="product-card-category">{product.category}</span>
              <h1 className="product-detail-name">{product.name}</h1>

              {/* With variants the price and the stock belong to the one
                  that is chosen, so this block follows the picker rather
                  than quoting a range the shopper cannot buy. */}
              {hasVariants ? (
                <VariantPrice />
              ) : (
                <div className="d-flex align-items-center gap-3 flex-wrap mb-3">
                  <span className="product-detail-price">
                    {formatPrice(product.price)}
                  </span>

                  {product.in_stock ? (
                    <span className="stock-badge">In stock · {stock} left</span>
                  ) : (
                    <span className="stock-badge out">Out of stock</span>
                  )}
                </div>
              )}

              {/* The picker renders the description, swapping it per variant,
                so printing it here too would show it twice. */}
              {hasVariants ? null : product.description ? (
                <p className="product-detail-description">
                  {product.description}
                </p>
              ) : (
                <p className="product-detail-description text-body-secondary">
                  No description yet.
                </p>
              )}

              {product.seller ? (
                <section
                  className="product-seller-panel"
                  aria-label="Seller information"
                >
                  <div className="product-seller-heading">
                    <div>
                      <span className="product-seller-label">Sold by</span>
                      <div className="product-seller-name">
                        <strong>{product.seller.name}</strong>
                        {product.seller.is_verified ? (
                          <VerifiedSellerBadge />
                        ) : null}
                      </div>
                    </div>

                    <div
                      className="product-seller-score"
                      aria-label={
                        sellerRating === null
                          ? "Seller has no ratings yet"
                          : `Seller rating ${sellerRating.toFixed(1)} out of 5 from ${sellerRatingCount} ratings`
                      }
                    >
                      {sellerRating === null ? (
                        <span>New seller</span>
                      ) : (
                        <>
                          <span
                            className="seller-rating-star-icon"
                            aria-hidden="true"
                          >
                            &#9733;
                          </span>
                          <strong>{sellerRating.toFixed(1)}</strong>
                          <span>
                            {sellerRatingCount} rating
                            {sellerRatingCount === 1 ? "" : "s"}
                          </span>
                        </>
                      )}
                    </div>
                  </div>

                  {user?.id === product.seller.id ? (
                    <p className="seller-rating-owner-note mb-0">
                      This is your store. Sellers cannot rate their own store.
                    </p>
                  ) : user ? (
                    <SellerRatingForm
                      productSlug={product.slug}
                      sellerId={product.seller.id}
                      initialScore={ownSellerRating?.score ?? null}
                    />
                  ) : null}
                </section>
              ) : null}

              <hr className="product-detail-divider" />

              {/* Products with options get the picker; plain ones keep the
                single button. */}
              {hasVariants ? (
                <VariantPicker
                  productId={product.id}
                  fallbackDescription={product.description}
                />
              ) : (
                <AddToCartButton
                  productId={product.id}
                  inStock={product.in_stock}
                  maxQuantity={product.stock}
                  withQuantity
                />
              )}

              <dl className="product-detail-meta mt-4 mb-0">
                <div>
                  <dt>Category</dt>
                  <dd>{product.category}</dd>
                </div>
                <div>
                  <dt>Availability</dt>
                  <dd>
                    {!product.in_stock
                      ? "None"
                      : hasVariants
                        ? `${stock} units across ${product.variants?.length ?? 0} variants`
                        : `${stock} units`}
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </VariantSelectionProvider>

      {related.length ? (
        <section className="mt-5">
          <h2 className="section-title mb-3">More in {product.category}</h2>
          <div className="row row-cols-2 row-cols-md-3 row-cols-lg-4 g-3">
            {related.map((item) => (
              <div className="col" key={item.id}>
                <ProductCard product={item} />
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </main>
  );
}
