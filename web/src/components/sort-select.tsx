"use client";

import { useRouter, useSearchParams } from "next/navigation";

const OPTIONS = [
  { value: "newest", label: "Newest" },
  { value: "price_asc", label: "Price: low to high" },
  { value: "price_desc", label: "Price: high to low" },
  { value: "name", label: "Name: A to Z" },
];

export function SortSelect() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const current = searchParams.get("sort") ?? "newest";

  return (
    <label className="sort-select">
      <span className="sort-select-label">Sort</span>
      <select
        className="form-select form-select-sm"
        value={current}
        onChange={(event) => {
          // Replace only the sort key so the active filters survive.
          const next = new URLSearchParams(searchParams);
          if (event.target.value === "newest") {
            next.delete("sort");
          } else {
            next.set("sort", event.target.value);
          }
          const query = next.toString();
          router.push(query ? `/products?${query}` : "/products");
        }}
      >
        {OPTIONS.map((option) => (
          <option value={option.value} key={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}
