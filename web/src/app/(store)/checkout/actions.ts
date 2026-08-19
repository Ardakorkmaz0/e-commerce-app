"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { authorizedFetch } from "@/lib/auth";

import type { CheckoutState } from "./checkout-state";

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

/**
 * Places the order and hands the shopper their receipt.
 *
 * The idempotency key comes from the form, generated once when the page
 * loaded. A refresh therefore re-sends the same key and the API returns
 * the order that already exists instead of opening a second one.
 */
export async function placeOrder(
  _previousState: CheckoutState,
  formData: FormData,
): Promise<CheckoutState> {
  const addressId = Number(getText(formData, "address_id"));
  const paymentMethodId = Number(getText(formData, "payment_method_id"));
  const idempotencyKey = getText(formData, "idempotency_key");

  if (!addressId) {
    return { message: "Choose a delivery address first.", success: false };
  }
  if (!paymentMethodId) {
    return { message: "Choose a payment method first.", success: false };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch("/orders/", {
      method: "POST",
      body: JSON.stringify({
        address_id: addressId,
        payment_method_id: paymentMethodId,
        idempotency_key: idempotencyKey,
      }),
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    return { message: "Could not reach the server.", success: false };
  }

  if (!response) {
    return {
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    // The API writes these for the shopper — "Your card was declined.",
    // "only 2 left" — so they are shown as they arrive.
    let message = "The order could not be placed.";
    try {
      const body = (await response.json()) as Record<string, unknown>;
      const first = Object.values(body)[0];
      if (Array.isArray(first) && first.length) {
        message = String(first[0]);
      } else if (typeof first === "string") {
        message = first;
      }
    } catch {
      // Not a validation error; the default message stands.
    }
    return { message, success: false };
  }

  const order = (await response.json()) as { order_number: string };

  // The badge, the cart and the order list have all moved on.
  revalidatePath("/cart");
  revalidatePath("/myorders");
  redirect(`/myorders/${order.order_number}?placed=1`);
}
