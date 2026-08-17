"use server";

import { revalidatePath } from "next/cache";

import { authorizedFetch } from "@/lib/auth";

export type SellerRatingFormState = {
  score: number | null;
  message: string;
  success: boolean;
};

type RatingResponse = {
  score: number | null;
};

async function readErrorMessage(response: Response): Promise<string> {
  try {
    const payload = (await response.json()) as Record<string, unknown>;
    if (typeof payload.detail === "string") {
      return payload.detail;
    }
    const scoreErrors = payload.score;
    if (Array.isArray(scoreErrors) && scoreErrors.length) {
      return scoreErrors.map(String).join(" ");
    }
  } catch {
    // A non-JSON response is handled with the generic message below.
  }
  return "Could not update your seller rating.";
}

export async function updateSellerRating(
  productSlug: string,
  sellerId: number,
  previousState: SellerRatingFormState,
  formData: FormData,
): Promise<SellerRatingFormState> {
  if (!Number.isInteger(sellerId) || sellerId <= 0) {
    return {
      score: previousState.score,
      message: "This seller is unavailable.",
      success: false,
    };
  }

  const endpoint = `/sellers/${sellerId}/rating/`;
  const intent = formData.get("intent");
  const isRemove = intent === "remove";
  const rawScore = Number(formData.get("score"));

  if (!isRemove && (!Number.isInteger(rawScore) || rawScore < 1 || rawScore > 5)) {
    return {
      score: previousState.score,
      message: "Choose a rating from 1 to 5 stars.",
      success: false,
    };
  }

  let response: Response | null;
  try {
    response = await authorizedFetch(endpoint, {
      method: isRemove ? "DELETE" : "PUT",
      headers: isRemove ? undefined : { "Content-Type": "application/json" },
      body: isRemove ? undefined : JSON.stringify({ score: rawScore }),
    });
  } catch {
    return {
      score: previousState.score,
      message: "Could not reach the server. Please try again.",
      success: false,
    };
  }

  if (!response || response.status === 401) {
    return {
      score: previousState.score,
      message: "Your session has expired. Please sign in again.",
      success: false,
    };
  }

  if (!response.ok) {
    return {
      score: previousState.score,
      message: await readErrorMessage(response),
      success: false,
    };
  }

  let savedScore: number | null = null;
  if (!isRemove) {
    const payload = (await response.json()) as RatingResponse;
    savedScore = typeof payload.score === "number" ? payload.score : rawScore;
  }

  revalidatePath(`/products/${productSlug}`);

  return {
    score: savedScore,
    message: isRemove ? "Your rating was removed." : "Your rating was saved.",
    success: true,
  };
}
