import "server-only";

import { authorizedFetch } from "./auth";

export type Address = {
  id: number;
  label: string;
  recipient_name: string;
  phone_number: string;
  address_line_1: string;
  address_line_2: string;
  district: string;
  city: string;
  postal_code: string;
  country_code: string;
  is_default: boolean;
  created_at: string;
  updated_at: string;
};

function isAddress(value: unknown): value is Address {
  if (!value || typeof value !== "object") {
    return false;
  }

  const address = value as Partial<Address>;
  return (
    typeof address.id === "number" &&
    typeof address.label === "string" &&
    typeof address.recipient_name === "string" &&
    typeof address.phone_number === "string" &&
    typeof address.address_line_1 === "string" &&
    typeof address.address_line_2 === "string" &&
    typeof address.district === "string" &&
    typeof address.city === "string" &&
    typeof address.postal_code === "string" &&
    typeof address.country_code === "string" &&
    typeof address.is_default === "boolean" &&
    typeof address.created_at === "string" &&
    typeof address.updated_at === "string"
  );
}

export async function fetchAddresses(): Promise<Address[]> {
  try {
    const response = await authorizedFetch("/auth/addresses/");
    if (!response?.ok) {
      return [];
    }

    const payload = (await response.json()) as unknown;
    return Array.isArray(payload) ? payload.filter(isAddress) : [];
  } catch {
    return [];
  }
}

export async function fetchAddress(addressId: number): Promise<Address | null> {
  if (!Number.isInteger(addressId) || addressId <= 0) {
    return null;
  }

  try {
    const response = await authorizedFetch(`/auth/addresses/${addressId}/`);
    if (!response?.ok) {
      return null;
    }

    const payload = (await response.json()) as unknown;
    return isAddress(payload) ? payload : null;
  } catch {
    return null;
  }
}

export function getSelectedAddress(addresses: Address[]): Address | null {
  return addresses.find((address) => address.is_default) ?? addresses[0] ?? null;
}

export function formatAddressDestination(address: Address | null): string {
  if (!address) {
    return "Add address";
  }

  return [address.district, address.city].filter(Boolean).join(", ") || address.label;
}
