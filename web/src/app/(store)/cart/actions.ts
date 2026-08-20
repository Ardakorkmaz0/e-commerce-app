"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

export type CartActionState = {
  message: string;
  success: boolean;
};

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

/** The API reports stock problems in `detail`; surface that, not a guess. */
async function readMessage(response: Response): Promise<string> {
  try {
    const payload = (await response.json()) as Record<string, unknown>;
    const detail = payload.detail;
    if (Array.isArray(detail) && detail.length) {
      return String(detail[0]);
    }
    if (typeof detail === "string") {
      return detail;
    }
  } catch {
    // Fall through to the generic message.
  }
  return "Could not update your cart.";
}

/**
 * Every cart change refreshes the pages that show a cart total, including
 * the navbar badge, which lives in the store layout.
 */
function revalidateCart() {
  revalidatePath("/cart");
  revalidatePath("/", "layout");
}

export async function addToCart(
  _previousState: CartActionState,
  formData: FormData,
): Promise<CartActionState> {
  const productId = Number(getText(formData, "product_id"));
  const quantity = Number(getText(formData, "quantity") || "1");

  // Empty for a product without options, and the API rejects a variant
  // sent for one of those, so it only travels when the picker set it.
  const variantId = Number(getText(formData, "variant_id"));
  const variant =
    Number.isFinite(variantId) && variantId > 0 ? variantId : null;

  if (!Number.isFinite(productId) || productId <= 0) {
    return { message: "That product could not be found.", success: false };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch("/cart/items/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        product_id: productId,
        quantity,
        ...(variant === null ? {} : { variant_id: variant }),
      }),
    });
  } catch {
    return { message: "Could not reach the server.", success: false };
  }

  if (!response) {
    return { message: "Please sign in to use your cart.", success: false };
  }
  if (!response.ok) {
    return { message: await readMessage(response), success: false };
  }

  revalidateCart();
  return { message: "Added to your cart.", success: true };
}

export async function updateCartItem(formData: FormData): Promise<void> {
  const itemId = getText(formData, "item_id");
  const quantity = Number(getText(formData, "quantity"));
  if (!itemId || !Number.isFinite(quantity) || quantity < 1) return;

  try {
    await authorizedFetch(`/cart/items/${itemId}/`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ quantity }),
    });
  } catch {
    // The page re-reads the cart, so it will show the real state.
  }

  revalidateCart();
}

export async function removeCartItem(formData: FormData): Promise<void> {
  const itemId = getText(formData, "item_id");
  if (!itemId) return;

  try {
    await authorizedFetch(`/cart/items/${itemId}/`, { method: "DELETE" });
  } catch {
    // Same here.
  }

  revalidateCart();
}

export async function clearCart(): Promise<void> {
  try {
    await authorizedFetch("/cart/", { method: "DELETE" });
  } catch {
    // Same here.
  }

  revalidateCart();
}
