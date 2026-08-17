"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

export type PaymentActionState = {
  errors: Record<string, string[]>;
  message: string;
  success: boolean;
};

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

async function readErrors(response: Response): Promise<Record<string, string[]>> {
  try {
    const payload = (await response.json()) as Record<string, unknown>;
    return Object.fromEntries(
      Object.entries(payload).map(([field, value]) => [
        field,
        Array.isArray(value) ? value.map(String) : [String(value)],
      ]),
    );
  } catch {
    return {};
  }
}

/**
 * Sends the card to the API, which validates it and keeps only the brand,
 * the last four digits and a token.
 *
 * The number passes through this action and is never written anywhere: not
 * to the returned state, not to a log, not to the revalidated page. On a
 * validation error the form is told which field was wrong, not what was in
 * it, so nothing has to be echoed back.
 */
export async function addPaymentMethod(
  _previousState: PaymentActionState,
  formData: FormData,
): Promise<PaymentActionState> {
  const body = {
    card_number: getText(formData, "card_number"),
    security_code: getText(formData, "security_code"),
    holder_name: getText(formData, "holder_name").trim(),
    exp_month: Number(getText(formData, "exp_month")),
    exp_year: Number(getText(formData, "exp_year")),
    is_default: formData.get("is_default") === "on",
  };

  let response: Response | null;
  try {
    response = await authorizedFetch("/auth/payment-methods/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    return { errors: {}, message: "Could not reach the server.", success: false };
  }

  if (!response) {
    return {
      errors: {},
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    const errors = await readErrors(response);
    return {
      errors,
      message: Object.keys(errors).length ? "" : "Could not save this card.",
      success: false,
    };
  }

  revalidatePath("/profile/payment-methods");
  return { errors: {}, message: "", success: true };
}

export async function selectPaymentMethod(formData: FormData): Promise<void> {
  const id = getText(formData, "id");
  if (!id) return;

  try {
    await authorizedFetch(`/auth/payment-methods/${id}/`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ is_default: true }),
    });
  } catch {
    // The page re-renders from the API, so it will show the real state.
  }

  revalidatePath("/profile/payment-methods");
}

export async function deletePaymentMethod(formData: FormData): Promise<void> {
  const id = getText(formData, "id");
  if (!id) return;

  try {
    await authorizedFetch(`/auth/payment-methods/${id}/`, { method: "DELETE" });
  } catch {
    // Same here: the list is the source of truth on the next render.
  }

  revalidatePath("/profile/payment-methods");
}
