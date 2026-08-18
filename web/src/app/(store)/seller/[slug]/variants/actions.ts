"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

import type { VariantActionState } from "./variant-state";

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

function getIds(formData: FormData, name: string): number[] {
  return formData
    .getAll(name)
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value) && value > 0);
}

async function readErrors(response: Response): Promise<VariantActionState> {
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
    message: Object.keys(errors).length ? "" : "Could not save the variant.",
    success: false,
  };
}

/**
 * Builds the request body.
 *
 * Same reasoning as the product form: JSON unless a file is attached, so
 * that an empty list can actually be sent. `price` is a nullable override,
 * so an empty box means "use the product price" and has to go as null
 * rather than "".
 */
function buildPayload(formData: FormData, optionValues: number[]) {
  const image = formData.get("image");
  const hasFile = image instanceof File && image.size > 0;

  const price = getText(formData, "price").trim();
  const fields = {
    price: price === "" ? null : price,
    stock: getText(formData, "stock").trim() || "0",
    description: getText(formData, "description").trim(),
    image_url: getText(formData, "image_url").trim(),
    is_active: formData.get("is_active") === "on",
  };

  if (!hasFile) {
    return {
      body: JSON.stringify({ ...fields, option_values: optionValues }),
      headers: { "Content-Type": "application/json" },
    };
  }

  const payload = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    // A null price cannot be expressed over multipart, so it is left out
    // and the previous value stays — which is what PATCH means anyway.
    if (value === null) continue;
    payload.append(key, String(value));
  }
  for (const id of optionValues) {
    payload.append("option_values", String(id));
  }
  payload.append("image", image as File);

  return { body: payload, headers: undefined };
}

/** Creates every combination of the ticked values that does not exist yet. */
export async function generateVariants(
  slug: string,
  _previousState: VariantActionState,
  formData: FormData,
): Promise<VariantActionState> {
  const valueIds = getIds(formData, "value_ids");
  if (!valueIds.length) {
    return {
      errors: {},
      message: "Tick the options this product comes in.",
      success: false,
    };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(
      `/seller/products/${slug}/variants/generate/`,
      {
        method: "POST",
        body: JSON.stringify({ value_ids: valueIds }),
        headers: { "Content-Type": "application/json" },
      },
    );
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
  if (response.status === 404) {
    return { errors: {}, message: "This product is not yours.", success: false };
  }
  if (!response.ok) {
    return readErrors(response);
  }

  const body = (await response.json()) as { created: number; skipped: number };
  revalidatePath(`/seller/${slug}/edit`);

  return {
    errors: {},
    message:
      body.created === 0
        ? "Every combination already exists."
        : `Added ${body.created} variant${body.created === 1 ? "" : "s"}` +
          (body.skipped ? `, skipped ${body.skipped} that already existed.` : "."),
    success: true,
  };
}

export async function updateVariant(
  slug: string,
  variantId: number,
  _previousState: VariantActionState,
  formData: FormData,
): Promise<VariantActionState> {
  // The options are not editable from the row form — changing them would
  // silently turn one variant into another — so only the rest is sent.
  const payload = buildPayload(formData, []);
  const body =
    typeof payload.body === "string"
      ? JSON.stringify(
          Object.fromEntries(
            Object.entries(
              JSON.parse(payload.body) as Record<string, unknown>,
            ).filter(([key]) => key !== "option_values"),
          ),
        )
      : payload.body;

  let response: Response | null;
  try {
    response = await authorizedFetch(
      `/seller/products/${slug}/variants/${variantId}/`,
      { method: "PATCH", body, headers: payload.headers },
    );
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
  if (response.status === 404) {
    return { errors: {}, message: "This variant is not yours.", success: false };
  }
  if (!response.ok) {
    return readErrors(response);
  }

  revalidatePath(`/seller/${slug}/edit`);
  return { errors: {}, message: "Saved.", success: true };
}

export async function deleteVariant(formData: FormData): Promise<void> {
  const slug = getText(formData, "slug");
  const variantId = getText(formData, "variant_id");
  if (!slug || !variantId) {
    return;
  }

  try {
    await authorizedFetch(`/seller/products/${slug}/variants/${variantId}/`, {
      method: "DELETE",
    });
  } catch {
    // Falls through to the revalidate; the list will show the real state.
  }

  revalidatePath(`/seller/${slug}/edit`);
}

/**
 * Adds one option the seller typed, creating its group when needed.
 *
 * Called straight from a click rather than a form: the "+" inputs sit
 * inside the generator's own form, and a form cannot be nested.
 */
export async function addOption(
  slug: string,
  input: { attributeId?: number; attributeName?: string; name: string; swatchColor?: string },
): Promise<VariantActionState> {
  const name = input.name.trim();
  if (!name) {
    return { errors: {}, message: "Type a name for the option.", success: false };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(`/seller/products/${slug}/options/`, {
      method: "POST",
      body: JSON.stringify({
        attribute_id: input.attributeId,
        attribute_name: input.attributeName?.trim() ?? "",
        name,
        swatch_color: input.swatchColor ?? "",
      }),
      headers: { "Content-Type": "application/json" },
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
  if (response.status === 404) {
    return { errors: {}, message: "This product is not yours.", success: false };
  }
  if (!response.ok) {
    return readErrors(response);
  }

  const body = (await response.json()) as { created: boolean };
  revalidatePath(`/seller/${slug}/edit`);

  return {
    errors: {},
    message: body.created ? `Added "${name}".` : `"${name}" already existed.`,
    success: true,
  };
}
