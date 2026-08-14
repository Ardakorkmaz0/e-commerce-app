import Link from "next/link";
import { notFound } from "next/navigation";

import { ProductCard } from "@/components/product-card";
import { fetchProduct, fetchProducts, formatPrice } from "@/lib/products";

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

  // Other products from the same category, current one removed.
  const related = (await fetchProducts({ category: product.category_slug }))
    .filter((item) => item.id !== product.id)
    .slice(0, 4);

  return (
    <main className="container py-4">
      <nav aria-label="Breadcrumb" className="product-breadcrumb mb-3">
        <Link href="/products">Products</Link>
        <span aria-hidden="true"> / </span>
        <Link href={`/products?category=${product.category_slug}`}>
          {product.category}
        </Link>
      </nav>

      <div className="row g-4 align-items-start">
        {/* Image */}
        <div className="col-12 col-lg-6">
          <div className="product-detail-media">
            {product.image_url ? (
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

            <div className="d-flex align-items-center gap-3 flex-wrap mb-3">
              <span className="product-detail-price">
                {formatPrice(product.price)}
              </span>

              {product.in_stock ? (
                <span className="stock-badge">In stock · {product.stock} left</span>
              ) : (
                <span className="stock-badge out">Out of stock</span>
              )}
            </div>

            {product.description ? (
              <p className="product-detail-description">{product.description}</p>
            ) : (
              <p className="product-detail-description text-body-secondary">
                No description yet.
              </p>
            )}

            <hr className="product-detail-divider" />

            <div className="d-flex align-items-center gap-2 mb-3">
              <label className="form-label mb-0" htmlFor="quantity">
                Quantity
              </label>
              <input
                id="quantity"
                type="number"
                className="form-control product-detail-quantity"
                defaultValue={1}
                min={1}
                max={Math.max(product.stock, 1)}
                disabled={!product.in_stock}
              />
            </div>

            {/* TODO: enable once the cart API exists */}
            <button
              className="btn signin-submit-button w-100 py-2"
              type="button"
              disabled
            >
              {product.in_stock ? "Add to cart (coming soon)" : "Out of stock"}
            </button>

            <dl className="product-detail-meta mt-4 mb-0">
              <div>
                <dt>Category</dt>
                <dd>{product.category}</dd>
              </div>
              <div>
                <dt>Availability</dt>
                <dd>{product.in_stock ? `${product.stock} units` : "None"}</dd>
              </div>
            </dl>
          </div>
        </div>
      </div>

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
