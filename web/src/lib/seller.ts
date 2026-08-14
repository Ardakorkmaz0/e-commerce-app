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
