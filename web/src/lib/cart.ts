import "server-only";

import { authorizedFetch } from "./auth";

export type CartItem = {
  id: number;
  product_id: number;
  variant_id: number | null;
  name: string;
  slug: string;
  /** "White / 2 controllers / 1 TB", empty for products without options. */
  option_label: string;
  image_url: string;
  quantity: number;
  /** Decimal as a string, exactly as the backend stores it. */
  unit_price: string;
  line_total: string;
  available_stock: number;
  has_stock_issue: boolean;
};

export type Cart = {
  id: number;
  items: CartItem[];
  item_count: number;
  subtotal: string;
  has_stock_issues: boolean;
};

const EMPTY_CART: Cart = {
  id: 0,
  items: [],
  item_count: 0,
  subtotal: "0.00",
  has_stock_issues: false,
};

export async function fetchCart(): Promise<Cart> {
  try {
    const response = await authorizedFetch("/cart/");
    if (!response?.ok) {
      return EMPTY_CART;
    }
    return (await response.json()) as Cart;
  } catch {
    return EMPTY_CART;
  }
}

/**
 * Just the badge number.
 *
 * The navbar renders on every page, so it asks for the cart and reads one
 * field rather than pulling a separate endpoint into existence.
 */
export async function fetchCartCount(): Promise<number> {
  const cart = await fetchCart();
  return cart.item_count;
}
