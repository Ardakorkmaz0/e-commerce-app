import type { Metadata } from "next";

import { ActiveFilters, FilterPanel } from "@/components/filter-panel";
import { ProductCard } from "@/components/product-card";
import { SortSelect } from "@/components/sort-select";
import { fetchCategories, fetchFacets, fetchProducts } from "@/lib/products";

export const metadata: Metadata = {
  title: "Products",
};

// In Next.js 16 searchParams is a Promise and must be awaited.
type ProductsPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function firstValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value[0] ?? "";
  return value ?? "";
}

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  const params = await searchParams;

  const category = firstValue(params.category);
  const q = firstValue(params.q);

  // Everything that is not the category or the search text is an attribute
  // filter, so new attributes work without changing this page.
  const attributes: Record<string, string> = {};
  for (const [key, value] of Object.entries(params)) {
    if (key === "category" || key === "q") continue;
    const single = firstValue(value);
    if (single) attributes[key] = single;
  }

  const [products, categories, facets] = await Promise.all([
    fetchProducts({ category, q, attributes }),
    fetchCategories(),
    fetchFacets({ category, q }),
  ]);

  const categoryName = categories.find((item) => item.slug === category)?.name;

  // Rebuilt here so the filter links can extend the current query string.
  const currentParams = new URLSearchParams();
  if (category) currentParams.set("category", category);
  if (q) currentParams.set("q", q);
  for (const [key, value] of Object.entries(attributes)) {
    currentParams.set(key, value);
  }

  // The panel is worth showing whenever there is anything to filter by.
  const showPanel = facets.attributes.length > 0 || Boolean(facets.price.max);

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-2">
        <h1 className="section-title mb-0">{categoryName ?? "All Products"}</h1>
        <div className="d-flex align-items-center gap-3">
          <span className="text-body-secondary small">
            {q ? `Search: "${q}" · ` : null}
            {products.length} product{products.length === 1 ? "" : "s"}
          </span>
          <SortSelect />
        </div>
      </div>

      <ActiveFilters facets={facets} searchParams={currentParams} />

      <div className="row g-4 mt-0">
        {showPanel ? (
          <div className="col-12 col-lg-3">
            <FilterPanel facets={facets} searchParams={currentParams} />
          </div>
        ) : null}

        <div className={showPanel ? "col-12 col-lg-9" : "col-12"}>
          {products.length ? (
            <div
              className={
                showPanel
                  ? "row row-cols-2 row-cols-lg-3 g-3"
                  : "row row-cols-2 row-cols-md-3 row-cols-lg-4 g-3"
              }
            >
              {products.map((product) => (
                <div className="col" key={product.id}>
                  <ProductCard product={product} />
                </div>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <p className="mb-0">No products matched your filters.</p>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
