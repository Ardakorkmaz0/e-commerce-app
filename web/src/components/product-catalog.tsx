import Link from "next/link";

import {
  ActiveFilters,
  FilterForm,
  FilterPanel,
} from "@/components/filter-panel";
import { InfiniteProductGrid } from "@/components/infinite-product-grid";
import { SortSelect } from "@/components/sort-select";
import { getProductImage } from "@/lib/product-images";
import {
  fetchCategories,
  fetchFacets,
  fetchProductPage,
} from "@/lib/products";

export type CatalogSearchParams = Record<
  string,
  string | string[] | undefined
>;

function firstValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value[0] ?? "";
  return value ?? "";
}

type ProductCatalogProps = {
  searchParams: CatalogSearchParams;
};

export async function ProductCatalog({ searchParams }: ProductCatalogProps) {
  const category = firstValue(searchParams.category);
  const q = firstValue(searchParams.q);

  const filters: Record<string, string> = {};
  for (const [key, value] of Object.entries(searchParams)) {
    if (
      key === "category" ||
      key === "q" ||
      key === "page" ||
      key === "page_size"
    ) {
      continue;
    }
    const single = firstValue(value);
    if (single) filters[key] = single;
  }

  const [productPage, categories, facets] = await Promise.all([
    fetchProductPage({ category, q, attributes: filters }),
    fetchCategories(),
    fetchFacets({ category, q }),
  ]);
  const products = productPage.results;

  const categoryName = categories.find((item) => item.slug === category)?.name;
  const currentParams = new URLSearchParams();
  if (category) currentParams.set("category", category);
  if (q) currentParams.set("q", q);
  for (const [key, value] of Object.entries(filters)) {
    currentParams.set(key, value);
  }

  const hasQuery = currentParams.size > 0;
  // Categories count too. Without them the panel could be withheld on a
  // page with no attributes, and on a phone that is the only way to pick a
  // department — the strip is hidden there and so is the search picker.
  const showPanel =
    facets.categories.length > 0 ||
    facets.attributes.length > 0 ||
    Boolean(facets.price.max);

  // Shown on the mobile Filters button. Category, search and sort are not
  // filters in this sense: they have their own controls.
  const activeFilterCount = [...currentParams.entries()]
    .filter(([key]) => !["category", "q", "sort"].includes(key))
    .reduce((total, [, value]) => total + value.split(",").filter(Boolean).length, 0);
  const departmentMap = new Map<
    string,
    { name: string; slug: string; products: typeof products }
  >();
  for (const product of products) {
    const department = departmentMap.get(product.category_slug) ?? {
      name: product.category,
      slug: product.category_slug,
      products: [],
    };
    department.products.push(product);
    departmentMap.set(product.category_slug, department);
  }
  const featuredDepartments = [...departmentMap.values()]
    .filter((department) => department.products.length >= 2)
    .slice(0, 4);

  return (
    <main className="marketplace-page">
      {!hasQuery && featuredDepartments.length ? (
        <section
          className="marketplace-featured"
          aria-label="Featured departments"
        >
          <div className="container marketplace-department-cards">
            {featuredDepartments.map((department) => (
              <article className="department-showcase-card" key={department.slug}>
                <h2>Shop {department.name}</h2>

                <div
                  className={`department-showcase-products count-${department.products.length}`}
                >
                  {department.products.slice(0, 3).map((product) => (
                    <Link
                      className="department-showcase-product"
                      href={`/products/${product.slug}`}
                      key={product.id}
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={getProductImage(product)}
                        alt={product.name}
                        loading="lazy"
                        decoding="async"
                      />
                      <span>{product.name}</span>
                    </Link>
                  ))}
                </div>

                <Link
                  className="department-showcase-link"
                  href={`/products?category=${department.slug}`}
                >
                  Explore {department.name}
                </Link>
              </article>
            ))}
          </div>
        </section>
      ) : null}

      {/* Hidden below lg at the markup level rather than in CSS, so the
          rule cannot be lost to cascade order. The filter offcanvas has a
          Department group, and the navbar search has its own picker. */}
      <nav
        className="navbar navbar-expand-lg marketplace-departments sticky-top d-none d-lg-flex"
        aria-label="Shop by department"
      >
        <div className="container marketplace-departments-inner">
          <Link
            className={`marketplace-department-link${category ? "" : " active"}`}
            href="/products"
          >
            All products
          </Link>
          {categories.map((item) => (
            <Link
              className={`marketplace-department-link${category === item.slug ? " active" : ""}`}
              href={`/products?category=${item.slug}`}
              key={item.id}
            >
              {item.name}
            </Link>
          ))}
        </div>
      </nav>

      <section className="container marketplace-catalog" id="product-catalog">
        <div className="marketplace-toolbar">
          <div>
            <span className="marketplace-toolbar-label">
              {q ? `Results for “${q}”` : "Shop the catalog"}
            </span>
            <h2>{categoryName ?? "Explore all products"}</h2>
          </div>

          <div className="marketplace-toolbar-actions">
            {/* Below lg the panel lives in an offcanvas, so it needs a way
                in. Bootstrap's bundle is already loaded, so no extra
                JavaScript is involved. */}
            {showPanel ? (
              <button
                className="btn filter-toggle d-lg-none"
                type="button"
                data-bs-toggle="offcanvas"
                data-bs-target="#filterOffcanvas"
                aria-controls="filterOffcanvas"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="16"
                  height="16"
                  fill="currentColor"
                  viewBox="0 0 16 16"
                  aria-hidden="true"
                >
                  <path
                    fillRule="evenodd"
                    d="M6 10.5a.5.5 0 0 1 .5-.5h3a.5.5 0 0 1 0 1h-3a.5.5 0 0 1-.5-.5m-2-3a.5.5 0 0 1 .5-.5h7a.5.5 0 0 1 0 1h-7a.5.5 0 0 1-.5-.5m-2-3a.5.5 0 0 1 .5-.5h11a.5.5 0 0 1 0 1h-11a.5.5 0 0 1-.5-.5"
                  />
                </svg>
                Filters
                {activeFilterCount > 0 ? (
                  <span className="filter-toggle-count">{activeFilterCount}</span>
                ) : null}
              </button>
            ) : null}

            <span className="marketplace-result-count">
              {productPage.count} product{productPage.count === 1 ? "" : "s"}
            </span>
            <SortSelect />
          </div>
        </div>

        <ActiveFilters facets={facets} searchParams={currentParams} />

        <div className="row g-4 mt-0">
          {showPanel ? (
            <>
              {/* Sidebar from lg up */}
              <div className="col-lg-3 col-xl-2 d-none d-lg-block">
                <FilterPanel facets={facets} searchParams={currentParams} />
              </div>

              {/* Same panel, slid in from the side on small screens */}
              <div
                className="offcanvas offcanvas-start filter-offcanvas d-lg-none"
                tabIndex={-1}
                id="filterOffcanvas"
                aria-labelledby="filterOffcanvasLabel"
              >
                <div className="offcanvas-header">
                  <h2 className="offcanvas-title h6 mb-0" id="filterOffcanvasLabel">
                    Filters
                  </h2>
                  <button
                    type="button"
                    className="btn-close"
                    data-bs-dismiss="offcanvas"
                    aria-label="Close"
                  />
                </div>
                {/* A form, not links: on a phone nothing should apply until
                    the footer button is pressed. */}
                <div className="offcanvas-body p-0 d-flex flex-column">
                  <FilterForm
                    facets={facets}
                    searchParams={currentParams}
                    resultCount={productPage.count}
                  />
                </div>
              </div>
            </>
          ) : null}

          <div className={showPanel ? "col-12 col-lg-9 col-xl-10" : "col-12"}>

            {products.length ? (
              <InfiniteProductGrid
                initialPage={productPage}
                queryString={currentParams.toString()}
                gridClassName={
                  showPanel
                    ? "row row-cols-2 row-cols-md-3 row-cols-xl-4 g-3"
                    : "row row-cols-2 row-cols-md-3 row-cols-lg-4 row-cols-xxl-5 g-3"
                }
                key={currentParams.toString() || "all-products"}
              />
            ) : (
              <div className="empty-state marketplace-empty-state">
                <h3>No products found</h3>
                <p className="mb-3">Try another search or remove a filter.</p>
                <Link className="btn signin-submit-button" href="/products">
                  View all products
                </Link>
              </div>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}
