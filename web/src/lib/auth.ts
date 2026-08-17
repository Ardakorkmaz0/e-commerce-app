import "server-only";

import { cookies } from "next/headers";

export const ACCESS_TOKEN_COOKIE = "vader_access_token";
export const REFRESH_TOKEN_COOKIE = "vader_refresh_token";

export type AuthenticatedUser = {
  id: number;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  store_name: string;
  is_verified_seller: boolean;
  is_staff: boolean;
  is_seller: boolean;
};

export function getApiBaseUrl(): string {
  return process.env.API_BASE_URL ?? "http://127.0.0.1:8000/api/v1";
}

async function requestCurrentUser(accessToken: string): Promise<AuthenticatedUser | null> {
  try {
    const response = await fetch(`${getApiBaseUrl()}/auth/me/`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
      cache: "no-store",
    });

    if (!response.ok) {
      return null;
    }

    return (await response.json()) as AuthenticatedUser;
  } catch {
    return null;
  }
}

export async function refreshAccessToken(refreshToken: string): Promise<string | null> {
  try {
    const response = await fetch(`${getApiBaseUrl()}/auth/token/refresh/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ refresh: refreshToken }),
      cache: "no-store",
    });

    if (!response.ok) {
      return null;
    }

    const payload = (await response.json()) as { access?: unknown };
    return typeof payload.access === "string" ? payload.access : null;
  } catch {
    return null;
  }
}

/**
 * Calls the API with the signed-in user's access token, refreshing it once
 * if it has expired. Returns null when there is no usable session.
 */
export async function authorizedFetch(
  path: string,
  init: RequestInit = {},
): Promise<Response | null> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get(ACCESS_TOKEN_COOKIE)?.value;
  const refreshToken = cookieStore.get(REFRESH_TOKEN_COOKIE)?.value;

  const send = (token: string) =>
    fetch(`${getApiBaseUrl()}${path}`, {
      ...init,
      headers: { ...init.headers, Authorization: `Bearer ${token}` },
      cache: "no-store",
    });

  let response: Response | null = null;
  if (accessToken) {
    response = await send(accessToken);
  }

  // Access tokens live 15 minutes, so an expired one is routine.
  if ((!response || response.status === 401) && refreshToken) {
    const renewed = await refreshAccessToken(refreshToken);
    if (renewed) {
      try {
        cookieStore.set(ACCESS_TOKEN_COOKIE, renewed, {
          httpOnly: true,
          secure: process.env.NODE_ENV === "production",
          sameSite: "lax",
          path: "/",
        });
      } catch {
        // Cookies are read-only while rendering a page; the refreshed token
        // still serves this request, it just is not persisted here.
      }
      response = await send(renewed);
    }
  }

  return response;
}

export async function getCurrentUser(): Promise<AuthenticatedUser | null> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get(ACCESS_TOKEN_COOKIE)?.value;
  const refreshToken = cookieStore.get(REFRESH_TOKEN_COOKIE)?.value;

  if (accessToken) {
    const user = await requestCurrentUser(accessToken);
    if (user) {
      return user;
    }
  }

  if (!refreshToken) {
    return null;
  }

  const refreshedAccessToken = await refreshAccessToken(refreshToken);
  if (!refreshedAccessToken) {
    return null;
  }

  return requestCurrentUser(refreshedAccessToken);
}
