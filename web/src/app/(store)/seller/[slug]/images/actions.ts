"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

import type { VariantActionState } from "../variants/variant-state";

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
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
    message: Object.keys(errors).length ? "" : "Could not save the photo.",
    success: false,
  };
}

/**
 * Adds one photo to the strip, by upload or by link.
 *
 * Multipart whenever a file is attached, because that is the only way a
 * file travels; JSON otherwise so `variant` can be sent as a real null.
 */
export async function addImage(
  slug: string,
  _previousState: VariantActionState,
  formData: FormData,
): Promise<VariantActionState> {
  const file = formData.get("image");
  const hasFile = file instanceof File && file.size > 0;
  const link = getText(formData, "image_url").trim();
  const alt = getText(formData, "alt").trim();
  const variant = getText(formData, "variant");

  if (!hasFile && !link) {
    return {
      errors: {},
      message: "Upload a file or paste a link.",
      success: false,
    };
  }

  let body: BodyInit;
  let headers: Record<string, string> | undefined;

  if (hasFile) {
    const payload = new FormData();
    payload.append("image", file as File);
    if (link) payload.append("image_url", link);
    payload.append("alt", alt);
    if (variant) payload.append("variant", variant);
    body = payload;
  } else {
    body = JSON.stringify({
      image_url: link,
      alt,
      variant: variant ? Number(variant) : null,
    });
    headers = { "Content-Type": "application/json" };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(`/seller/products/${slug}/images/`, {
      method: "POST",
      body,
      headers,
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

  revalidatePath(`/seller/${slug}/edit`);
  return { errors: {}, message: "Photo added.", success: true };
}

/** Moves a photo to a new index; the server shifts the rest along. */
export async function moveImage(formData: FormData): Promise<void> {
  const slug = getText(formData, "slug");
  const imageId = getText(formData, "image_id");
  const position = getText(formData, "position");
  if (!slug || !imageId || position === "") {
    return;
  }

  try {
    await authorizedFetch(`/seller/products/${slug}/images/${imageId}/`, {
      method: "PATCH",
      body: JSON.stringify({ position: Number(position) }),
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    // Falls through to the revalidate; the strip shows the real order.
  }

  revalidatePath(`/seller/${slug}/edit`);
}

export async function deleteImage(formData: FormData): Promise<void> {
  const slug = getText(formData, "slug");
  const imageId = getText(formData, "image_id");
  if (!slug || !imageId) {
    return;
  }

  try {
    await authorizedFetch(`/seller/products/${slug}/images/${imageId}/`, {
      method: "DELETE",
    });
  } catch {
    // Same as above.
  }

  revalidatePath(`/seller/${slug}/edit`);
}

/** Edits a photo where it sits: its picture, its caption, its variant. */
export async function updateImage(
  slug: string,
  imageId: number,
  _previousState: VariantActionState,
  formData: FormData,
): Promise<VariantActionState> {
  const file = formData.get("image");
  const hasFile = file instanceof File && file.size > 0;
  const link = getText(formData, "image_url").trim();
  const alt = getText(formData, "alt").trim();
  const variant = getText(formData, "variant");

  let body: BodyInit;
  let headers: Record<string, string> | undefined;

  if (hasFile) {
    const payload = new FormData();
    payload.append("image", file as File);
    payload.append("alt", alt);
    if (variant) payload.append("variant", variant);
    body = payload;
  } else {
    if (!link) {
      return {
        errors: {},
        message: "Paste a link or choose a file.",
        success: false,
      };
    }
    body = JSON.stringify({
      image_url: link,
      alt,
      variant: variant ? Number(variant) : null,
    });
    headers = { "Content-Type": "application/json" };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(
      `/seller/products/${slug}/images/${imageId}/`,
      { method: "PATCH", body, headers },
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
    return { errors: {}, message: "This photo is not yours.", success: false };
  }
  if (!response.ok) {
    return readErrors(response);
  }

  revalidatePath(`/seller/${slug}/edit`);
  return { errors: {}, message: "Saved.", success: true };
}
