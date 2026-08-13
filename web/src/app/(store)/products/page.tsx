import type { Metadata } from "next";

import { ProductGridPlaceholder } from "@/components/product-card-placeholder";

export const metadata: Metadata = {
  title: "Products",
};

// In Next.js 16 searchParams is a Promise and must be awaited.
type ProductsPageProps = {
  searchParams: Promise<{ q?: string; category?: string }>;
};

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  const { q, category } = await searchParams;

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
        <h1 className="section-title mb-0">Products</h1>

        {/* Show which filter is active so the query is visible to the user */}
        {q || category ? (
          <span className="text-body-secondary small">
            {q ? `Search: "${q}"` : null}
            {q && category ? " · " : null}
            {category ? `Category: ${category}` : null}
          </span>
        ) : null}
      </div>

      {/* TODO: fetch real products once the ecommerce API is ready */}
      <ProductGridPlaceholder count={12} />
    </main>
  );
}
