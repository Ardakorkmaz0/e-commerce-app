export const PRODUCT_PAGE_SIZE = 12;

export type SellerSummary = {
  id: number;
  name: string;
  is_verified: boolean;
  rating: number | null;
  rating_count: number;
};

export type Product = {
  id: number;
  name: string;
  slug: string;
  description: string;
  price: string;
  stock: number;
  in_stock: boolean;
  category: string;
  category_slug: string;
  image_url: string;
  seller: SellerSummary | null;
};

export type PaginatedProducts = {
  count: number;
  next: string | null;
  previous: string | null;
  results: Product[];
};

export function formatPrice(price: string): string {
  const amount = Number(price);
  return Number.isFinite(amount) ? `$${amount.toFixed(2)}` : price;
}
