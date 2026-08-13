import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Categories",
};

// TODO: replace with real categories from the backend
const CATEGORIES = ["Electronics", "Clothing", "Books", "Home", "Sports"];

export default function CategoriesPage() {
  return (
    <main className="container py-4">
      <h1 className="section-title mb-3">Categories</h1>

      <div className="row row-cols-2 row-cols-md-3 row-cols-lg-5 g-3">
        {CATEGORIES.map((category) => (
          <div className="col" key={category}>
            <Link
              className="product-card d-flex flex-column align-items-center justify-content-center text-decoration-none p-4"
              href={`/products?category=${encodeURIComponent(category)}`}
            >
              <span className="fw-semibold" style={{ color: "var(--site-text)" }}>
                {category}
              </span>
            </Link>
          </div>
        ))}
      </div>
    </main>
  );
}
