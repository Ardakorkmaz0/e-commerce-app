import "server-only";

import { authorizedFetch } from "./auth";

/**
 * A saved card as the API describes it.
 *
 * There is no card number here, and there is none in the database either.
 * The API only ever returns what is safe to show: brand, last four digits
 * and expiry.
 */
export type PaymentMethod = {
  id: number;
  brand: "visa" | "mastercard";
  brand_display: string;
  last4: string;
  exp_month: number;
  exp_year: number;
  holder_name: string;
  is_default: boolean;
  is_expired: boolean;
  created_at: string;
};

export async function fetchPaymentMethods(): Promise<PaymentMethod[]> {
  try {
    const response = await authorizedFetch("/auth/payment-methods/");
    if (!response?.ok) {
      return [];
    }
    const payload = await response.json();
    return Array.isArray(payload) ? (payload as PaymentMethod[]) : [];
  } catch {
    return [];
  }
}

/** "12 / 2030", zero padded so the column lines up. */
export function formatExpiry(method: PaymentMethod): string {
  return `${String(method.exp_month).padStart(2, "0")} / ${method.exp_year}`;
}
