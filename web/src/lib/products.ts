import "server-only";

import { getApiBaseUrl } from "./auth";
import {
  PRODUCT_PAGE_SIZE,
  type PaginatedProducts,
  type Product,
} from "./catalog";

export { formatPrice, type PaginatedProducts, type Product } from "./catalog";

export type Category = {
  id: number;
  name: string;
  slug: string;
};

// The catalog endpoints are public, so no Authorization header is needed.
// Failures return an empty list: a backend outage should degrade the page,
// not crash it.
export async function fetchCategories(): Promise<Category[]> {
  try {
    const response = await fetch(`${getApiBaseUrl()}/categories/`, {
      cache: "no-store",
    });
    if (!response.ok) {
      return [];
    }
    return (await response.json()) as Category[];
  } catch {
    return [];
  }
}

export type FacetValue = {
  name: string;
  slug: string;
  count: number;
};

export type Facet = {
  name: string;
  slug: string;
  values: FacetValue[];
};

export type CategoryFacet = {
  name: string;
  slug: string;
  count: number;
};

export type AttributeOption = {
  id: number;
  name: string;
  slug: string;
  categories: number[];
  values: { id: number; name: string; slug: string }[];
};

/** Every attribute with its values — used by the seller form. */
export async function fetchAttributes(): Promise<AttributeOption[]> {
  try {
    const response = await fetch(`${getApiBaseUrl()}/attributes/`, {
      cache: "no-store",
    });
    if (!response.ok) {
      return [];
    }
    return (await response.json()) as AttributeOption[];
  } catch {
    return [];
  }
}

export type PriceBounds = {
  min: string;
  max: string;
  ranges: {
    slug: string;
    label: string;
    count: number;
  }[];
};

export type Facets = {
  categories: CategoryFacet[];
  availability: {
    in_stock: number;
    low_stock: number;
    out_of_stock: number;
  };
  attributes: Facet[];
  price: PriceBounds;
};

const EMPTY_FACETS: Facets = {
  categories: [],
  availability: { in_stock: 0, low_stock: 0, out_of_stock: 0 },
  attributes: [],
  price: { min: "", max: "", ranges: [] },
};

/** Describes the filter panel: attributes, their values, and price bounds. */
export async function fetchFacets(
  filters: { category?: string; q?: string } = {},
): Promise<Facets> {
  const params = new URLSearchParams();
  if (filters.category) {
    params.set("category", filters.category);
  }
  if (filters.q) {
    params.set("q", filters.q);
  }

  try {
    const response = await fetch(`${getApiBaseUrl()}/facets/?${params}`, {
      cache: "no-store",
    });
    if (!response.ok) {
      return EMPTY_FACETS;
    }
    return (await response.json()) as Facets;
  } catch {
    return EMPTY_FACETS;
  }
}

export type ProductFilters = {
  category?: string;
  q?: string;
  /** Attribute filters, e.g. { memory: "8-gb", series: "3060,4060" }. */
  attributes?: Record<string, string>;
  page?: number;
  pageSize?: number;
};

const EMPTY_PRODUCT_PAGE: PaginatedProducts = {
  count: 0,
  next: null,
  previous: null,
  results: [],
};

export async function fetchProductPage(
  filters: ProductFilters = {},
): Promise<PaginatedProducts> {
  const params = new URLSearchParams();
  if (filters.category) {
    params.set("category", filters.category);
  }
  if (filters.q) {
    params.set("q", filters.q);
  }
  for (const [slug, value] of Object.entries(filters.attributes ?? {})) {
    if (value) {
      params.set(slug, value);
    }
  }
  if (filters.page && filters.page > 1) {
    params.set("page", String(filters.page));
  }
  if (filters.pageSize) {
    params.set("page_size", String(filters.pageSize));
  }

  const query = params.toString();
  const url = `${getApiBaseUrl()}/products/${query ? `?${query}` : ""}`;

  try {
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) {
      return EMPTY_PRODUCT_PAGE;
    }
    return (await response.json()) as PaginatedProducts;
  } catch {
    return EMPTY_PRODUCT_PAGE;
  }
}

export async function fetchProducts(
  filters: ProductFilters = {},
): Promise<Product[]> {
  const page = await fetchProductPage({
    ...filters,
    pageSize: filters.pageSize ?? PRODUCT_PAGE_SIZE,
  });
  return page.results;
}

export async function fetchProduct(slug: string): Promise<Product | null> {
  try {
    const response = await fetch(`${getApiBaseUrl()}/products/${slug}/`, {
      cache: "no-store",
    });
    if (!response.ok) return null;
    return (await response.json()) as Product;
  } catch {
    return null;
  }
}
