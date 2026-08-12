"use server";

import { redirect } from "next/navigation";

export type SignUpFormState = {
  errors: Record<string, string[]>;
  message: string;
};

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);

  return typeof value === "string" ? value : "";
}

function normalizeErrors(payload: unknown): Record<string, string[]> {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return {};
  }

  return Object.fromEntries(
    Object.entries(payload).map(([field, value]) => {
      if (Array.isArray(value)) {
        return [field, value.map(String)];
      }

      return [field, [String(value)]];
    }),
  );
}

export async function signUp(
  _previousState: SignUpFormState,
  formData: FormData,
): Promise<SignUpFormState> {
  const password = getText(formData, "password");
  const passwordConfirm = getText(formData, "password_confirm");

  if (password !== passwordConfirm) {
    return {
      errors: { password_confirm: ["Passwords do not match."] },
      message: "Please correct the form errors.",
    };
  }

  const apiBaseUrl = process.env.API_BASE_URL ?? "http://127.0.0.1:8000/api/v1";
  let response: Response;

  try {
    response = await fetch(`${apiBaseUrl}/auth/register/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        username: getText(formData, "username"),
        email: getText(formData, "email"),
        first_name: getText(formData, "first_name"),
        last_name: getText(formData, "last_name"),
        password,
        password_confirm: passwordConfirm,
      }),
      cache: "no-store",
    });
  } catch {
    return {
      errors: {},
      message: "The registration service is unavailable. Please try again.",
    };
  }

  if (!response.ok) {
    let payload: unknown = null;

    try {
      payload = await response.json();
    } catch {
      payload = null;
    }

    return {
      errors: normalizeErrors(payload),
      message: "Please correct the form errors.",
    };
  }

  redirect("/signin?registered=1");
}
