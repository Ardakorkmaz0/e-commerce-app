export const PRODUCT_PAGE_SIZE = 12;

export type SellerSummary = {
  id: number;
  name: string;
  is_verified: boolean;
  rating: number | null;
  rating_count: number;
};

export type OptionValue = {
  id: number;
  name: string;
  slug: string;
  /** Hex colour when the value should render as a swatch, else empty. */
  swatch_color: string;
};

export type OptionGroup = {
  name: string;
  slug: string;
  values: OptionValue[];
};

export type ProductVariant = {
  id: number;
  sku: string;
  /** Sorted, so a selection can be compared against it directly. */
  option_value_ids: number[];
  option_label: string;
  price: string;
  stock: number;
  in_stock: boolean;
  description: string;
  image_url: string;
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

  // Present on the detail endpoint. A product with no variants is sold as
  // itself; with variants, one has to be chosen before adding to the cart.
  has_variants?: boolean;
  total_stock?: number;
  images?: ProductImage[];
  variants?: ProductVariant[];
  option_groups?: OptionGroup[];
  price_from?: string;
  price_to?: string;
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

/** One photo in a product's gallery strip. */
export type ProductImage = {
  id: number;
  url: string;
  alt: string;
  /** Null for photos that stay on screen whichever variant is chosen. */
  variant: number | null;
  position: number;
};
