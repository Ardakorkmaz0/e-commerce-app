import "server-only";

import { authorizedFetch } from "./auth";

export type SellerRatingSnapshot = {
  seller_id: number;
  score: number | null;
  rating: number | null;
  rating_count: number;
};

export async function fetchSellerRating(
  sellerId: number,
): Promise<SellerRatingSnapshot | null> {
  if (!Number.isInteger(sellerId) || sellerId <= 0) {
    return null;
  }

  try {
    const response = await authorizedFetch(`/sellers/${sellerId}/rating/`);
    if (!response?.ok) {
      return null;
    }
    return (await response.json()) as SellerRatingSnapshot;
  } catch {
    return null;
  }
}
