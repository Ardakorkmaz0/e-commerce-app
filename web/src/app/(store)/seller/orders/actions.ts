"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

/** Marks this seller's lines as posted; other sellers' are untouched. */
export async function shipOrder(formData: FormData): Promise<void> {
  const value = formData.get("order_number");
  const orderNumber = typeof value === "string" ? value : "";
  if (!orderNumber) return;

  try {
    await authorizedFetch(`/seller/orders/${orderNumber}/ship/`, {
      method: "POST",
    });
  } catch {
    // Falls through to the revalidate; the list shows the real state.
  }

  revalidatePath("/seller/orders");
}
