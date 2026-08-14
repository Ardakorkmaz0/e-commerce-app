import type { Metadata } from "next";
import Link from "next/link";

import { ProductCard } from "@/components/product-card";
import { fetchProducts } from "@/lib/products";

export const metadata: Metadata = {
  title: "Home",
};

export default async function HomePage() {
  // Categories live in the navbar dropdown, so the home page only shows
  // products. The newest ones come first (Product.Meta.ordering).
  const products = await fetchProducts();
  const featured = products.slice(0, 8);

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-3">
        <h2 className="section-title mb-0">Featured Products</h2>
        <Link href="/products" className="small">
          See all products
        </Link>
      </div>

      {featured.length ? (
        <div className="row row-cols-2 row-cols-md-3 row-cols-lg-4 g-3">
          {featured.map((product) => (
            <div className="col" key={product.id}>
              <ProductCard product={product} />
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-state">
          <p className="mb-0">
            No products yet. Add some from the{" "}
            <a href="http://127.0.0.1:8000/admin/ecommerce/product/">admin panel</a>.
          </p>
        </div>
      )}
    </main>
  );
}
