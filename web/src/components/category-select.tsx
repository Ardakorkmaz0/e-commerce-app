"use client";

import { useSearchParams } from "next/navigation";

// Shape is declared locally rather than imported from lib/products, which is
// server-only. Types are erased at build time, but keeping this file free of
// that import makes the client boundary obvious.
type CategoryOption = {
  id: number;
  name: string;
  slug: string;
};

export function CategorySelect({ categories }: { categories: CategoryOption[] }) {
  const searchParams = useSearchParams();
  const current = searchParams.get("category") ?? "";

  return (
    <select
      // Remounting on `current` keeps the shown department in sync with the
      // URL after each navigation, without making this a controlled input.
      key={current}
      defaultValue={current}
      className="form-select site-search-category"
      id="searchCategory"
      name="category"
      onChange={(event) => {
        // Picking a department filters right away, like clicking a category.
        // Submitting the parent form keeps whatever is typed in the search box.
        event.currentTarget.form?.requestSubmit();
      }}
    >
      <option value="">All Departments</option>
      {categories.map((category) => (
        <option key={category.id} value={category.slug}>
          {category.name}
        </option>
      ))}
    </select>
  );
}
