"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import {
  ACCESS_TOKEN_COOKIE,
  getApiBaseUrl,
  REFRESH_TOKEN_COOKIE,
} from "@/lib/auth";

export type SignInFormState = {
  message: string;
  username: string;
};

function getText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

export async function signIn(
  _previousState: SignInFormState,
  formData: FormData,
): Promise<SignInFormState> {
  const username = getText(formData, "username").trim();
  const password = getText(formData, "password");
  const rememberMe = formData.get("remember_me") === "on";

  let response: Response;
  try {
    response = await fetch(`${getApiBaseUrl()}/auth/token/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ username, password }),
      cache: "no-store",
    });
  } catch {
    return {
      message: "The sign-in service is unavailable. Please try again.",
      username,
    };
  }

  if (!response.ok) {
    return {
      message: "Invalid username or password.",
      username,
    };
  }

  const payload = (await response.json()) as {
    access?: unknown;
    refresh?: unknown;
  };

  if (typeof payload.access !== "string" || typeof payload.refresh !== "string") {
    return {
      message: "The sign-in response was invalid. Please try again.",
      username,
    };
  }

  const cookieStore = await cookies();
  const baseCookieOptions = {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/",
  };

  cookieStore.set(
    ACCESS_TOKEN_COOKIE,
    payload.access,
    rememberMe
      ? { ...baseCookieOptions, maxAge: 15 * 60 }
      : baseCookieOptions,
  );
  cookieStore.set(
    REFRESH_TOKEN_COOKIE,
    payload.refresh,
    rememberMe
      ? { ...baseCookieOptions, maxAge: 7 * 24 * 60 * 60 }
      : baseCookieOptions,
  );

  redirect("/");
}
