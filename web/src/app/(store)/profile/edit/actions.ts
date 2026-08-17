"use server";

import { refresh } from "next/cache";
import { cookies } from "next/headers";

import {
  ACCESS_TOKEN_COOKIE,
  getApiBaseUrl,
  REFRESH_TOKEN_COOKIE,
  refreshAccessToken,
} from "@/lib/auth";

export type EditProfileFormState = {
  errors: Record<string, string[]>;
  message: string;
  success: boolean;
};

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

// Sends the PATCH with a Bearer token. Returns the raw response so the
// caller can decide whether to retry with a refreshed token.
async function patchProfile(
  accessToken: string,
  body: Record<string, string>,
): Promise<Response> {
  return fetch(`${getApiBaseUrl()}/auth/me/`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body),
    cache: "no-store",
  });
}

export async function updateProfile(
  _previousState: EditProfileFormState,
  formData: FormData,
): Promise<EditProfileFormState> {
  const body = {
    email: getText(formData, "email").trim(),
    first_name: getText(formData, "first_name").trim(),
    last_name: getText(formData, "last_name").trim(),
    store_name: getText(formData, "store_name").trim(),
  };

  const cookieStore = await cookies();
  const accessToken = cookieStore.get(ACCESS_TOKEN_COOKIE)?.value;
  const refreshToken = cookieStore.get(REFRESH_TOKEN_COOKIE)?.value;

  if (!accessToken && !refreshToken) {
    return {
      errors: {},
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  let response: Response | null = null;
  try {
    if (accessToken) {
      response = await patchProfile(accessToken, body);
    }

    // The access token lives 15 minutes, so an expired one is expected.
    // Refresh once and retry before treating this as a failure.
    if ((!response || response.status === 401) && refreshToken) {
      const renewedAccessToken = await refreshAccessToken(refreshToken);
      if (renewedAccessToken) {
        cookieStore.set(ACCESS_TOKEN_COOKIE, renewedAccessToken, {
          httpOnly: true,
          secure: process.env.NODE_ENV === "production",
          sameSite: "lax",
          path: "/",
        });
        response = await patchProfile(renewedAccessToken, body);
      }
    }
  } catch {
    return {
      errors: {},
      message: "Could not reach the server. Please try again.",
      success: false,
    };
  }

  if (!response) {
    return {
      errors: {},
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (response.status === 401) {
    return {
      errors: {},
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    // DRF returns {"email": ["..."]} for validation errors.
    let errors: Record<string, string[]> = {};
    try {
      const payload = (await response.json()) as Record<string, unknown>;
      errors = Object.fromEntries(
        Object.entries(payload).map(([field, value]) => [
          field,
          Array.isArray(value) ? value.map(String) : [String(value)],
        ]),
      );
    } catch {
      // A non-JSON body means the failure was not a validation error.
    }

    return {
      errors,
      message: Object.keys(errors).length ? "" : "Could not update your profile.",
      success: false,
    };
  }

  // The profile is read with cache: "no-store", so the page only needs a
  // re-render — refresh() re-runs the current route in this same response.
  refresh();

  return { errors: {}, message: "", success: true };
}
