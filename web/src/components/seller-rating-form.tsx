"use client";

import { useActionState } from "react";

import {
  updateSellerRating,
  type SellerRatingFormState,
} from "@/app/(store)/products/[slug]/actions";

type SellerRatingFormProps = {
  productSlug: string;
  sellerId: number;
  initialScore: number | null;
};

export function SellerRatingForm({
  productSlug,
  sellerId,
  initialScore,
}: SellerRatingFormProps) {
  const initialState: SellerRatingFormState = {
    score: initialScore,
    message: "",
    success: false,
  };
  const action = updateSellerRating.bind(null, productSlug, sellerId);
  const [state, formAction, pending] = useActionState(action, initialState);

  return (
    <form action={formAction} className="seller-rating-form">
      <fieldset disabled={pending}>
        <legend>Rate this seller</legend>
        <div className="seller-rating-controls">
          <div
            className="seller-rating-stars"
            aria-label="Choose a seller rating"
            key={`${state.score ?? "none"}-${state.message}`}
          >
            {[5, 4, 3, 2, 1].map((score) => (
              <label
                className="seller-rating-option"
                key={score}
                title={`${score} star${score === 1 ? "" : "s"}`}
              >
                <input
                  className="visually-hidden"
                  type="radio"
                  name="score"
                  value={score}
                  defaultChecked={state.score === score}
                  required
                />
                <span className="seller-rating-star" aria-hidden="true">
                  &#9733;
                </span>
                <span className="visually-hidden">
                  {score} star{score === 1 ? "" : "s"}
                </span>
              </label>
            ))}
          </div>

          <div className="seller-rating-actions">
            <button
              className="btn btn-sm btn-primary"
              type="submit"
              name="intent"
              value="save"
            >
              {pending ? "Saving..." : "Save rating"}
            </button>
            {state.score !== null ? (
              <button
                className="btn btn-sm btn-link seller-rating-remove"
                type="submit"
                name="intent"
                value="remove"
                formNoValidate
              >
                Remove
              </button>
            ) : null}
          </div>
        </div>
      </fieldset>

      {state.message ? (
        <p
          className={`seller-rating-message ${state.success ? "success" : "error"}`}
          role={state.success ? "status" : "alert"}
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}
    </form>
  );
}
