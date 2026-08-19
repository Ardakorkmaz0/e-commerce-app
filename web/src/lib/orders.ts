import "server-only";

import { authorizedFetch } from "./auth";

export type OrderStatus =
  | "pending"
  | "paid"
  | "shipped"
  | "delivered"
  | "cancelled";

/**
 * A line as it was bought.
 *
 * Every field is the copy taken at checkout, so a product that has since
 * been renamed, repriced or deleted still reads the way the shopper
 * remembers it. `slug` may 404 for exactly that reason.
 */
export type OrderItem = {
  id: number;
  name: string;
  slug: string;
  option_label: string;
  seller_name: string;
  image_url: string;
  unit_price: string;
  quantity: number;
  line_total: string;
  is_shipped: boolean;
  shipped_at: string | null;
};

export type Order = {
  id: number;
  order_number: string;
  status: OrderStatus;
  status_display: string;
  currency: string;
  subtotal: string;
  shipping: string;
  total: string;
  item_count: number;
  items: OrderItem[];
  recipient_name: string;
  phone_number: string;
  address_line_1: string;
  address_line_2: string;
  district: string;
  city: string;
  postal_code: string;
  country_code: string;
  card_brand: string;
  card_last4: string;
  is_cancellable: boolean;
  /** Why an unpaid order is still unpaid; empty otherwise. */
  last_payment_error: string;
  created_at: string;
  paid_at: string | null;
  shipped_at: string | null;
  delivered_at: string | null;
  cancelled_at: string | null;
};

/** One order narrowed to a single seller's lines. */
export type SellerOrder = {
  id: number;
  order_number: string;
  status: OrderStatus;
  status_display: string;
  currency: string;
  items: Omit<OrderItem, "seller_name" | "is_shipped">[];
  seller_total: string;
  recipient_name: string;
  phone_number: string;
  address_line_1: string;
  address_line_2: string;
  district: string;
  city: string;
  postal_code: string;
  country_code: string;
  created_at: string;
  paid_at: string | null;
};

export async function fetchOrders(): Promise<Order[]> {
  try {
    const response = await authorizedFetch("/orders/");
    if (!response?.ok) {
      return [];
    }
    return (await response.json()) as Order[];
  } catch {
    return [];
  }
}

export async function fetchOrder(orderNumber: string): Promise<Order | null> {
  try {
    const response = await authorizedFetch(`/orders/${orderNumber}/`);
    if (!response?.ok) {
      return null;
    }
    return (await response.json()) as Order;
  } catch {
    return null;
  }
}

export async function fetchSellerOrders(): Promise<SellerOrder[]> {
  try {
    const response = await authorizedFetch("/seller/orders/");
    if (!response?.ok) {
      return [];
    }
    return (await response.json()) as SellerOrder[];
  } catch {
    return [];
  }
}

/** Colours the status badge; keeps the mapping in one place. */
export function statusTone(status: OrderStatus): string {
  switch (status) {
    case "delivered":
      return "delivered";
    case "shipped":
      return "shipped";
    case "cancelled":
      return "cancelled";
    case "pending":
      return "pending";
    default:
      return "paid";
  }
}
