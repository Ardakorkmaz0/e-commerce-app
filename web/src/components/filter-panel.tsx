import Link from "next/link";

import type { Facets } from "@/lib/products";

/**
 * Builds the URL for turning one value on or off.
 *
 * Filters live entirely in the query string, so every option is a plain
 * link. That keeps this a Server Component: no JavaScript, the back button
 * works, and a filtered list can be bookmarked or shared.
 */
function toggleHref(
  current: URLSearchParams,
  key: string,
  value: string,
): string {
  const next = new URLSearchParams(current);
  const selected = (next.get(key) ?? "").split(",").filter(Boolean);

  const updated = selected.includes(value)
    ? selected.filter((slug) => slug !== value)
    : [...selected, value];

  if (updated.length) {
    next.set(key, updated.join(","));
  } else {
    next.delete(key);
  }

  const query = next.toString();
  return query ? `/products?${query}` : "/products";
}

function withoutKey(current: URLSearchParams, key: string): string {
  const next = new URLSearchParams(current);
  next.delete(key);
  const query = next.toString();
  return query ? `/products?${query}` : "/products";
}

function singleValueHref(
  current: URLSearchParams,
  key: string,
  value: string,
  remove: string[] = [],
): string {
  const next = new URLSearchParams(current);
  if (next.get(key) === value) {
    next.delete(key);
  } else {
    next.set(key, value);
  }
  for (const item of remove) next.delete(item);
  const query = next.toString();
  return query ? `/products?${query}` : "/products";
}

type FilterPanelProps = {
  facets: Facets;
  searchParams: URLSearchParams;
};

export function FilterPanel({ facets, searchParams }: FilterPanelProps) {
  const { attributes, availability, categories, price } = facets;

  // Clearing keeps the category and the search text, drops everything else.
  const cleared = new URLSearchParams();
  const category = searchParams.get("category");
  const query = searchParams.get("q");
  if (category) cleared.set("category", category);
  if (query) cleared.set("q", query);

  const hasActiveFilters = [...searchParams.keys()].some(
    (key) => key !== "category" && key !== "q" && key !== "sort",
  );

  const selectedCategory = searchParams.get("category") ?? "";
  const selectedAvailability = searchParams.get("availability") ?? "";
  const selectedPriceRange = searchParams.get("price_range") ?? "";
  const minPrice = searchParams.get("min_price") ?? "";
  const maxPrice = searchParams.get("max_price") ?? "";

  return (
    <aside className="filter-panel">
      <div className="filter-panel-head">
        <h2 className="filter-panel-title mb-0">Filters</h2>
        {hasActiveFilters ? (
          <Link className="filter-clear" href={`/products?${cleared.toString()}`}>
            Clear all
          </Link>
        ) : null}
      </div>

      {/* Price range — a GET form, so the other filters travel as hidden
          inputs rather than being lost on submit. */}
      <details className="filter-group" open>
        <summary className="filter-group-title">Department</summary>
        <ul className="list-unstyled mb-0">
          {categories.map((item) => {
            const isSelected = selectedCategory === item.slug;
            return (
              <li key={item.slug}>
                <Link
                  className={`filter-option${isSelected ? " selected" : ""}`}
                  href={singleValueHref(searchParams, "category", item.slug)}
                >
                  <span className="filter-radio" aria-hidden="true">
                    {isSelected ? "\u2022" : ""}
                  </span>
                  <span className="filter-label">{item.name}</span>
                  <span className="filter-count">{item.count}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      </details>

      <details className="filter-group" open>
        <summary className="filter-group-title">Price</summary>
        <ul className="list-unstyled mb-2">
          {price.ranges.map((item) => {
            const isSelected = selectedPriceRange === item.slug;
            return (
              <li key={item.slug}>
                <Link
                  className={`filter-option${isSelected ? " selected" : ""}`}
                  href={singleValueHref(
                    searchParams,
                    "price_range",
                    item.slug,
                    ["min_price", "max_price"],
                  )}
                >
                  <span className="filter-radio" aria-hidden="true">
                    {isSelected ? "\u2022" : ""}
                  </span>
                  <span className="filter-label">{item.label}</span>
                  <span className="filter-count">{item.count}</span>
                </Link>
              </li>
            );
          })}
        </ul>
        <form className="filter-price" action="/products" method="get">
          {[...searchParams.entries()]
            .filter(
              ([key]) =>
                key !== "min_price" &&
                key !== "max_price" &&
                key !== "price_range",
            )
            .map(([key, value]) => (
              <input type="hidden" name={key} value={value} key={key} />
            ))}

          <div className="d-flex align-items-center gap-1">
            <input
              className="form-control form-control-sm"
              type="number"
              name="min_price"
              inputMode="decimal"
              min="0"
              step="0.01"
              placeholder={price.min || "min"}
              defaultValue={minPrice}
              aria-label="Minimum price"
            />
            <span className="filter-price-dash">–</span>
            <input
              className="form-control form-control-sm"
              type="number"
              name="max_price"
              inputMode="decimal"
              min="0"
              step="0.01"
              placeholder={price.max || "max"}
              defaultValue={maxPrice}
              aria-label="Maximum price"
            />
          </div>
          <button className="btn btn-sm filter-apply w-100 mt-2" type="submit">
            Apply
          </button>
        </form>
      </details>

      {/* Availability */}
      <details className="filter-group" open>
        <summary className="filter-group-title">Availability</summary>
        {[
          { value: "in_stock", label: "In stock", count: availability.in_stock },
          { value: "low_stock", label: "Low stock", count: availability.low_stock },
          {
            value: "out_of_stock",
            label: "Out of stock",
            count: availability.out_of_stock,
          },
        ].map((item) => {
          const isSelected = selectedAvailability === item.value;
          return (
            <Link
              className={`filter-option${isSelected ? " selected" : ""}`}
              href={singleValueHref(
                searchParams,
                "availability",
                item.value,
                ["in_stock"],
              )}
              key={item.value}
            >
              <span className="filter-radio" aria-hidden="true">
                {isSelected ? "\u2022" : ""}
              </span>
              <span className="filter-label">{item.label}</span>
              <span className="filter-count">{item.count}</span>
            </Link>
          );
        })}
      </details>

      {attributes.map((facet) => {
        const selected = (searchParams.get(facet.slug) ?? "")
          .split(",")
          .filter(Boolean);

        return (
          <details className="filter-group" key={facet.slug} open>
            <summary className="filter-group-title">{facet.name}</summary>
            <ul className="list-unstyled mb-0">
              {facet.values.map((value) => {
                const isSelected = selected.includes(value.slug);
                return (
                  <li key={value.slug}>
                    <Link
                      className={`filter-option${isSelected ? " selected" : ""}`}
                      href={toggleHref(searchParams, facet.slug, value.slug)}
                    >
                      <span className="filter-box" aria-hidden="true">
                        {isSelected ? "✓" : ""}
                      </span>
                      <span className="filter-label">{value.name}</span>
                      <span className="filter-count">{value.count}</span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </details>
        );
      })}
    </aside>
  );
}

/** The removable chips shown above the results, like the Turkish stores. */
export function ActiveFilters({
  facets,
  searchParams,
}: {
  facets: Facets;
  searchParams: URLSearchParams;
}) {
  const chips: { label: string; href: string }[] = [];

  const category = searchParams.get("category");
  if (category) {
    const value = facets.categories.find((item) => item.slug === category);
    chips.push({
      label: `Department: ${value?.name ?? category}`,
      href: withoutKey(searchParams, "category"),
    });
  }

  const priceRange = searchParams.get("price_range");
  if (priceRange) {
    const value = facets.price.ranges.find((item) => item.slug === priceRange);
    chips.push({
      label: value?.label ?? priceRange,
      href: withoutKey(searchParams, "price_range"),
    });
  }

  const minPrice = searchParams.get("min_price");
  const maxPrice = searchParams.get("max_price");
  if (minPrice || maxPrice) {
    const next = new URLSearchParams(searchParams);
    next.delete("min_price");
    next.delete("max_price");
    chips.push({
      label: `Price ${minPrice || "0"} – ${maxPrice || "∞"}`,
      href: `/products?${next.toString()}`,
    });
  }

  if (searchParams.get("in_stock") === "1") {
    chips.push({
      label: "In stock only",
      href: withoutKey(searchParams, "in_stock"),
    });
  }

  const availability = searchParams.get("availability");
  if (availability) {
    const labels: Record<string, string> = {
      in_stock: "In stock",
      low_stock: "Low stock",
      out_of_stock: "Out of stock",
    };
    chips.push({
      label: labels[availability] ?? availability,
      href: withoutKey(searchParams, "availability"),
    });
  }

  for (const facet of facets.attributes) {
    const selected = (searchParams.get(facet.slug) ?? "")
      .split(",")
      .filter(Boolean);

    for (const slug of selected) {
      const value = facet.values.find((item) => item.slug === slug);
      chips.push({
        label: `${facet.name}: ${value?.name ?? slug}`,
        href: toggleHref(searchParams, facet.slug, slug),
      });
    }
  }

  if (!chips.length) {
    return null;
  }

  return (
    <div className="active-filters">
      {chips.map((chip) => (
        <Link className="active-chip" href={chip.href} key={chip.label}>
          {chip.label}
          <span className="active-chip-x" aria-hidden="true">
            ×
          </span>
        </Link>
      ))}
    </div>
  );
}
