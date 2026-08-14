"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { authorizedFetch } from "@/lib/auth";

export type SellerFormState = {
  errors: Record<string, string[]>;
  message: string;
};

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

type Payload = {
  body: BodyInit;
  headers?: Record<string, string>;
};

/**
 * Rebuilds the submitted form for the API.
 *
 * JSON is used unless a file is attached. That is not a style choice: DRF
 * skips a many-to-many field entirely when an HTML form posts it with no
 * values, so unchecking every filter tag over multipart would leave the old
 * tags in place. JSON can carry an explicit empty list and clear them.
 * When a file is present, multipart is required and fetch sets the boundary,
 * so Content-Type is deliberately left unset.
 */
function buildPayload(formData: FormData): Payload {
  const image = formData.get("image");
  const hasFile = image instanceof File && image.size > 0;

  const values = formData
    .getAll("attribute_values")
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value) && value > 0);

  const fields = {
    name: getText(formData, "name").trim(),
    description: getText(formData, "description").trim(),
    price: getText(formData, "price").trim(),
    stock: getText(formData, "stock").trim(),
    category: getText(formData, "category"),
    image_url: getText(formData, "image_url").trim(),
    is_active: formData.get("is_active") === "on",
  };

  if (!hasFile) {
    return {
      body: JSON.stringify({ ...fields, attribute_values: values }),
      headers: { "Content-Type": "application/json" },
    };
  }

  const payload = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    payload.append(key, String(value));
  }
  for (const value of values) {
    payload.append("attribute_values", String(value));
  }
  payload.append("image", image as File);

  return { body: payload };
}

async function readErrors(response: Response): Promise<SellerFormState> {
  let errors: Record<string, string[]> = {};
  try {
    const body = (await response.json()) as Record<string, unknown>;
    errors = Object.fromEntries(
      Object.entries(body).map(([field, value]) => [
        field,
        Array.isArray(value) ? value.map(String) : [String(value)],
      ]),
    );
  } catch {
    // A non-JSON body means this was not a validation error.
  }

  return {
    errors,
    message: Object.keys(errors).length ? "" : "Could not save the product.",
  };
}

export async function createProduct(
  _previousState: SellerFormState,
  formData: FormData,
): Promise<SellerFormState> {
  const payload = buildPayload(formData);
  let response: Response | null;
  try {
    response = await authorizedFetch("/seller/products/", {
      method: "POST",
      body: payload.body,
      headers: payload.headers,
    });
  } catch {
    return { errors: {}, message: "Could not reach the server." };
  }

  if (!response) {
    return { errors: {}, message: "Your session has expired. Please sign in again." };
  }
  if (response.status === 403) {
    return { errors: {}, message: "You need a seller account to do this." };
  }
  if (!response.ok) {
    return readErrors(response);
  }

  revalidatePath("/seller");
  redirect("/seller");
}

export async function updateProduct(
  slug: string,
  _previousState: SellerFormState,
  formData: FormData,
): Promise<SellerFormState> {
  const payload = buildPayload(formData);
  let response: Response | null;
  try {
    response = await authorizedFetch(`/seller/products/${slug}/`, {
      method: "PATCH",
      body: payload.body,
      headers: payload.headers,
    });
  } catch {
    return { errors: {}, message: "Could not reach the server." };
  }

  if (!response) {
    return { errors: {}, message: "Your session has expired. Please sign in again." };
  }
  // The API filters by owner, so someone else's product simply is not found.
  if (response.status === 404) {
    return { errors: {}, message: "This product is not yours to edit." };
  }
  if (!response.ok) {
    return readErrors(response);
  }

  revalidatePath("/seller");
  redirect("/seller");
}

export async function deleteProduct(formData: FormData): Promise<void> {
  const slug = getText(formData, "slug");
  if (!slug) {
    return;
  }

  try {
    await authorizedFetch(`/seller/products/${slug}/`, { method: "DELETE" });
  } catch {
    // Falls through to the redirect; the list will show the real state.
  }

  revalidatePath("/seller");
  redirect("/seller");
}
