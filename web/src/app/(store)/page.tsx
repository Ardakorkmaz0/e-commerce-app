import type { Metadata } from "next";
import Link from "next/link";

import { ProductGridPlaceholder } from "@/components/product-card-placeholder";

export const metadata: Metadata = {
  title: "Home",
};

// TODO: replace with real categories from the backend
const CATEGORIES = ["All", "Electronics", "Clothing", "Books", "Home", "Sports"];

export default function HomePage() {
  return (
    <main className="container py-4">
      {/* Search — mirrors the SearchBar at the top of the Flutter home tab */}
      <form className="store-search d-flex mb-4" action="/products" method="get" role="search">
        <input
          className="form-control"
          type="search"
          name="q"
          placeholder="Search products..."
          aria-label="Search products"
        />
        <button className="btn" type="submit">
          Search
        </button>
      </form>

      {/* Categories — mirrors the horizontal FilterChip row */}
      <h2 className="section-title mb-2">Categories</h2>
      <div className="category-scroller d-flex gap-2 pb-2 mb-4">
        {CATEGORIES.map((category, index) => (
          <Link
            key={category}
            className={`category-chip${index === 0 ? " active" : ""}`}
            href={
              index === 0
                ? "/products"
                : `/products?category=${encodeURIComponent(category)}`
            }
          >
            {category}
          </Link>
        ))}
      </div>

      {/* Featured products — placeholder grid until the API exists */}
      <h2 className="section-title mb-3">Featured Products</h2>
      <ProductGridPlaceholder count={8} />
    </main>
  );
}
