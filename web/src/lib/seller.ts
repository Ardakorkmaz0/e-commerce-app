import "server-only";

import { authorizedFetch } from "./auth";

export type SellerProduct = {
  id: number;
  name: string;
  slug: string;
  description: string;
  price: string;
  stock: number;
  category: number;
  category_name: string;
  attribute_values: number[];
  image_url: string;
  image_display: string;
  is_active: boolean;
  created_at: string;
};

export async function fetchSellerProducts(): Promise<SellerProduct[]> {
  try {
    const response = await authorizedFetch("/seller/products/");
    if (!response?.ok) {
      return [];
    }
    return (await response.json()) as SellerProduct[];
  } catch {
    return [];
  }
}

export async function fetchSellerProduct(
  slug: string,
): Promise<SellerProduct | null> {
  try {
    const response = await authorizedFetch(`/seller/products/${slug}/`);
    if (!response?.ok) {
      return null;
    }
    return (await response.json()) as SellerProduct;
  } catch {
    return null;
  }
}

export type SellerVariant = {
  id: number;
  sku: string;
  option_values: number[];
  option_label: string;
  /** null means "same as the product price". */
  price: string | null;
  stock: number;
  description: string;
  image_url: string;
  image_display: string;
  is_active: boolean;
  position: number;
};

export async function fetchSellerVariants(
  slug: string,
): Promise<SellerVariant[]> {
  try {
    const response = await authorizedFetch(`/seller/products/${slug}/variants/`);
    if (!response?.ok) {
      return [];
    }
    return (await response.json()) as SellerVariant[];
  } catch {
    return [];
  }
}

export type SellerImage = {
  id: number;
  url: string;
  alt: string;
  /** Null for photos shown whichever variant is chosen. */
  variant: number | null;
  position: number;
};

export async function fetchSellerImages(slug: string): Promise<SellerImage[]> {
  try {
    const response = await authorizedFetch(`/seller/products/${slug}/images/`);
    if (!response?.ok) {
      return [];
    }
    return (await response.json()) as SellerImage[];
  } catch {
    return [];
  }
}
