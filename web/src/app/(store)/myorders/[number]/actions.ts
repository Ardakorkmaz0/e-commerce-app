"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

async function post(orderNumber: string, path: string): Promise<void> {
  try {
    await authorizedFetch(`/orders/${orderNumber}/${path}/`, {
      method: "POST",
    });
  } catch {
    // Falls through to the revalidate; the page shows the real state.
  }

  revalidatePath(`/myorders/${orderNumber}`);
  revalidatePath("/myorders");
}

/** Cancels the whole order; the API puts the stock back. */
export async function cancelOrder(formData: FormData): Promise<void> {
  const orderNumber = getText(formData, "order_number");
  if (!orderNumber) return;
  await post(orderNumber, "cancel");
}

/** The shopper confirming the parcel arrived. */
export async function confirmDelivery(formData: FormData): Promise<void> {
  const orderNumber = getText(formData, "order_number");
  if (!orderNumber) return;
  await post(orderNumber, "delivered");
}
