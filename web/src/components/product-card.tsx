import Link from "next/link";

import { formatPrice, type Product } from "@/lib/products";

export function ProductCard({ product }: { product: Product }) {
  return (
    <Link href={`/products/${product.slug}`} className="product-card-link">
      <article className="product-card d-flex flex-column h-100">
        <div className="product-card-media">
          {product.image_url ? (
            <img
              src={product.image_url}
              alt={product.name}
              className="product-card-image"
              loading="lazy"
            />
          ) : (
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="48"
              height="48"
              fill="currentColor"
              viewBox="0 0 16 16"
              aria-hidden="true"
            >
              <path d="M6.002 5.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0" />
              <path d="M2.002 1a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2zm12 1a1 1 0 0 1 1 1v6.5l-3.777-1.947a.5.5 0 0 0-.577.093l-3.71 3.71-2.66-1.772a.5.5 0 0 0-.63.062L1.002 12V3a1 1 0 0 1 1-1z" />
            </svg>
          )}
        </div>

        <div className="p-3 d-flex flex-column flex-grow-1">
          <span className="product-card-category">{product.category}</span>

          <h3 className="product-card-name">{product.name}</h3>

          <div className="mt-auto d-flex align-items-center justify-content-between gap-2">
            <span className="product-card-price">{formatPrice(product.price)}</span>

            {product.in_stock ? (
              <span className="product-card-stock">{product.stock} in stock</span>
            ) : (
              <span className="product-card-stock out">Out of stock</span>
            )}
          </div>
        </div>
      </article>
    </Link>
  );
}