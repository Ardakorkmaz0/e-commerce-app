import Link from "next/link";

import { getProductImage } from "@/lib/product-images";
import { formatPrice, type Product } from "@/lib/catalog";

import { VerifiedSellerBadge } from "./verified-seller-badge";

export function ProductCard({ product }: { product: Product }) {
  const imageUrl = getProductImage(product);

  return (
    <Link
      href={`/products/${product.slug}`}
      className="product-card-link"
      aria-label={`View ${product.name}`}
    >
      <article className="product-card d-flex flex-column h-100">
        <div className="product-card-media">
          {/* Product images can come from uploaded media or a remote URL. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={imageUrl}
            alt={product.name}
            className="product-card-image"
            loading="lazy"
            decoding="async"
          />
        </div>

        <div className="p-3 d-flex flex-column flex-grow-1">
          <span className="product-card-category">{product.category}</span>
          <h3 className="product-card-name">{product.name}</h3>

          {product.seller ? (
            <div className="product-card-seller">
              <div className="product-card-seller-name">
                <span>Sold by</span>
                <strong>{product.seller.name}</strong>
                {product.seller.is_verified ? (
                  <VerifiedSellerBadge compact />
                ) : null}
              </div>
              <span
                className="seller-rating-summary"
                aria-label={
                  product.seller.rating === null
                    ? "Seller has no ratings yet"
                    : `Seller rating ${product.seller.rating.toFixed(1)} out of 5 from ${product.seller.rating_count} ratings`
                }
              >
                {product.seller.rating === null ? (
                  "New seller"
                ) : (
                  <>
                    <span className="seller-rating-star-icon" aria-hidden="true">
                      &#9733;
                    </span>{" "}
                    {product.seller.rating.toFixed(1)}
                    <span className="seller-rating-count">
                      ({product.seller.rating_count})
                    </span>
                  </>
                )}
              </span>
            </div>
          ) : null}

          {product.description ? (
            <p className="product-card-description">{product.description}</p>
          ) : null}

          <div className="product-card-footer mt-auto">
            <span className="product-card-price">{formatPrice(product.price)}</span>

            {product.in_stock ? (
              <span className="product-card-stock">In stock · {product.stock}</span>
            ) : (
              <span className="product-card-stock out">Out of stock</span>
            )}
          </div>

          <span className="product-card-view">
            View product <span aria-hidden="true">→</span>
          </span>
        </div>
      </article>
    </Link>
  );
}
