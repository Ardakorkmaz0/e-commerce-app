"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";

import { authorizedFetch } from "@/lib/auth";
import { safeNext } from "@/lib/safe-next";

export type AddressFormState = {
  errors: Record<string, string[]>;
  message: string;
  success: boolean;
};

export type AddressActionState = {
  message: string;
  success: boolean;
};

type AddressBody = {
  label: string;
  recipient_name: string;
  phone_number: string;
  address_line_1: string;
  address_line_2: string;
  district: string;
  city: string;
  postal_code: string;
  country_code: string;
};

const FIELD_LIMITS: Record<keyof AddressBody, number> = {
  label: 50,
  recipient_name: 120,
  phone_number: 32,
  address_line_1: 200,
  address_line_2: 200,
  district: 100,
  city: 100,
  postal_code: 20,
  country_code: 2,
};

const REQUIRED_FIELDS: Array<keyof AddressBody> = [
  "label",
  "recipient_name",
  "phone_number",
  "address_line_1",
  "district",
  "city",
  "country_code",
];

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value.trim() : "";
}

function readAddressBody(formData: FormData): AddressBody {
  return {
    label: getText(formData, "label"),
    recipient_name: getText(formData, "recipient_name"),
    phone_number: getText(formData, "phone_number"),
    address_line_1: getText(formData, "address_line_1"),
    address_line_2: getText(formData, "address_line_2"),
    district: getText(formData, "district"),
    city: getText(formData, "city"),
    postal_code: getText(formData, "postal_code"),
    country_code: getText(formData, "country_code").toUpperCase(),
  };
}

function validateAddressBody(body: AddressBody): Record<string, string[]> {
  const errors: Record<string, string[]> = {};

  for (const field of REQUIRED_FIELDS) {
    if (!body[field]) {
      errors[field] = ["This field is required."];
    }
  }

  for (const [field, maxLength] of Object.entries(FIELD_LIMITS) as Array<
    [keyof AddressBody, number]
  >) {
    if (body[field].length > maxLength) {
      errors[field] = [`Ensure this field has no more than ${maxLength} characters.`];
    }
  }

  if (body.country_code && !/^[A-Z]{2}$/.test(body.country_code)) {
    errors.country_code = ["Enter a two-letter country code."];
  }

  return errors;
}

async function readApiErrors(
  response: Response,
  fallbackMessage: string,
): Promise<AddressFormState> {
  try {
    const payload = (await response.json()) as Record<string, unknown>;
    const errors: Record<string, string[]> = {};
    let message = fallbackMessage;

    for (const [field, value] of Object.entries(payload)) {
      if (field === "detail" && typeof value === "string") {
        message = value;
      } else if (Array.isArray(value)) {
        errors[field] = value.map(String);
      } else if (typeof value === "string") {
        errors[field] = [value];
      }
    }

    return {
      errors,
      message: Object.keys(errors).length ? "" : message,
      success: false,
    };
  } catch {
    return { errors: {}, message: fallbackMessage, success: false };
  }
}

async function saveAddress(
  endpoint: string,
  method: "POST" | "PATCH",
  formData: FormData,
): Promise<AddressFormState | null> {
  const body = readAddressBody(formData);
  const errors = validateAddressBody(body);
  if (Object.keys(errors).length) {
    return { errors, message: "", success: false };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(endpoint, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    return {
      errors: {},
      message: "Could not reach the server. Please try again.",
      success: false,
    };
  }

  if (!response || response.status === 401) {
    return {
      errors: {},
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    return readApiErrors(response, "Could not save this address.");
  }

  return null;
}

export async function createAddress(
  _previousState: AddressFormState,
  formData: FormData,
): Promise<AddressFormState> {
  const errorState = await saveAddress("/auth/addresses/", "POST", formData);
  if (errorState) {
    return errorState;
  }

  // Somebody sent here from checkout wants to carry on checking out, not
  // to land in their address book.
  const next = formData.get("next");
  redirect(
    safeNext(typeof next === "string" ? next : null) ?? "/profile/addresses",
  );
}

export async function updateAddress(
  addressId: number,
  _previousState: AddressFormState,
  formData: FormData,
): Promise<AddressFormState> {
  if (!Number.isInteger(addressId) || addressId <= 0) {
    return { errors: {}, message: "This address is unavailable.", success: false };
  }

  const errorState = await saveAddress(
    `/auth/addresses/${addressId}/`,
    "PATCH",
    formData,
  );
  if (errorState) {
    return errorState;
  }

  redirect("/profile/addresses");
}

export async function selectAddress(
  addressId: number,
  _previousState: AddressActionState,
  _formData: FormData,
): Promise<AddressActionState> {
  void _previousState;
  void _formData;

  if (!Number.isInteger(addressId) || addressId <= 0) {
    return { message: "This address is unavailable.", success: false };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(`/auth/addresses/${addressId}/`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ is_default: true }),
    });
  } catch {
    return {
      message: "Could not reach the server. Please try again.",
      success: false,
    };
  }

  if (!response || response.status === 401) {
    return {
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    const errorState = await readApiErrors(response, "Could not select this address.");
    return {
      message:
        errorState.message ||
        Object.values(errorState.errors).flat().join(" ") ||
        "Could not select this address.",
      success: false,
    };
  }

  refresh();
  return { message: "Delivery address updated.", success: true };
}

export async function deleteAddress(
  addressId: number,
  _previousState: AddressActionState,
  _formData: FormData,
): Promise<AddressActionState> {
  void _previousState;
  void _formData;

  if (!Number.isInteger(addressId) || addressId <= 0) {
    return { message: "This address is unavailable.", success: false };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(`/auth/addresses/${addressId}/`, {
      method: "DELETE",
    });
  } catch {
    return {
      message: "Could not reach the server. Please try again.",
      success: false,
    };
  }

  if (!response || response.status === 401) {
    return {
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    const errorState = await readApiErrors(response, "Could not delete this address.");
    return {
      message:
        errorState.message ||
        Object.values(errorState.errors).flat().join(" ") ||
        "Could not delete this address.",
      success: false,
    };
  }

  refresh();
  return { message: "Address deleted.", success: true };
}
