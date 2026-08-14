import "server-only";

import { getApiBaseUrl } from "./auth";

export type Category = {
  id: number;
  name: string;
  slug: string;
};

export type Product = {
  id: number;
  name: string;
  slug: string;
  description: string;
  // DRF serializes DecimalField as a string so the value keeps its exact
  // precision. Parse it only for formatting, never for money arithmetic.
  price: string;
  stock: number;
  in_stock: boolean;
  category: string;
  category_slug: string;
  image_url: string;
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
};

export type Facets = {
  attributes: Facet[];
  price: PriceBounds;
};

const EMPTY_FACETS: Facets = { attributes: [], price: { min: "", max: "" } };

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

export async function fetchProducts(
  filters: {
    category?: string;
    q?: string;
    /** Attribute filters, e.g. { brand: "rtx", series: "3060,4060" }. */
    attributes?: Record<string, string>;
  } = {},
): Promise<Product[]> {
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

  const query = params.toString();
  const url = `${getApiBaseUrl()}/products/${query ? `?${query}` : ""}`;

  try {
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) {
      return [];
    }
    return (await response.json()) as Product[];
  } catch {
    return [];
  }
}

// TODO: move the currency to configuration once orders are implemented.
export function formatPrice(price: string): string {
  const amount = Number(price);
  return Number.isFinite(amount) ? `$${amount.toFixed(2)}` : price;
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