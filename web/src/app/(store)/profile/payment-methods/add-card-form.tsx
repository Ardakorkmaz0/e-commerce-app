"use client";

import { useActionState, useState } from "react";

import { CardBrandLogo } from "@/components/card-brand-logo";

import { addPaymentMethod, type PaymentActionState } from "./actions";

const initialState: PaymentActionState = {
  errors: {},
  message: "",
  success: false,
};

/** Mirrors the server's detection so the brand mark can appear as you type. */
function detectBrand(digits: string): "visa" | "mastercard" | null {
  if (/^4/.test(digits)) return "visa";
  if (/^5[1-5]/.test(digits)) return "mastercard";
  if (/^2(2[2-9]|[3-6]|7[01]|720)/.test(digits)) return "mastercard";
  return null;
}

function groupDigits(digits: string): string {
  return digits.replace(/(.{4})/g, "$1 ").trim();
}

function FieldError({ errors }: { errors?: string[] }) {
  if (!errors?.length) return null;
  return (
    <div className="invalid-feedback d-block" role="alert">
      {errors.join(" ")}
    </div>
  );
}

export function AddCardForm() {
  const [state, formAction, pending] = useActionState(
    addPaymentMethod,
    initialState,
  );

  const [cardNumber, setCardNumber] = useState("");
  const [securityCode, setSecurityCode] = useState("");
  const brand = detectBrand(cardNumber.replace(/\D/g, ""));

  const currentYear = new Date().getFullYear();

  // Wipe the card fields the moment the save succeeds, so the number does
  // not sit in the DOM afterwards. Adjusted during render rather than in an
  // effect, which avoids a frame where the saved number is still on screen.
  const [wasSuccessful, setWasSuccessful] = useState(false);
  if (state.success !== wasSuccessful) {
    setWasSuccessful(state.success);
    if (state.success) {
      setCardNumber("");
      setSecurityCode("");
    }
  }

  return (
    <form action={formAction} className="profile-form">
      {state.success ? (
        <div className="alert alert-success" role="status">
          Card saved. Only the last four digits are stored.
        </div>
      ) : null}

      {state.message ? (
        <div className="alert alert-danger" role="alert" aria-live="polite">
          {state.message}
        </div>
      ) : null}

      <div className="mb-3">
        <label className="form-label" htmlFor="card_number">
          Card number
        </label>
        <div className="card-number-field">
          <input
            className="form-control"
            id="card_number"
            name="card_number"
            inputMode="numeric"
            autoComplete="cc-number"
            placeholder="1234 5678 9012 3456"
            required
            value={groupDigits(cardNumber.replace(/\D/g, ""))}
            onChange={(event) =>
              setCardNumber(event.target.value.replace(/\D/g, "").slice(0, 19))
            }
          />
          {brand ? <CardBrandLogo brand={brand} /> : null}
        </div>
        <div className="form-text">Visa and Mastercard are supported.</div>
        <FieldError errors={state.errors.card_number} />
      </div>

      <div className="mb-3">
        <label className="form-label" htmlFor="holder_name">
          Name on card
        </label>
        <input
          className="form-control"
          id="holder_name"
          name="holder_name"
          autoComplete="cc-name"
          maxLength={120}
          required
        />
        <FieldError errors={state.errors.holder_name} />
      </div>

      <div className="row g-2 mb-3">
        <div className="col-4">
          <label className="form-label" htmlFor="exp_month">
            Month
          </label>
          <select
            className="form-select"
            id="exp_month"
            name="exp_month"
            autoComplete="cc-exp-month"
            required
            defaultValue=""
          >
            <option value="" disabled>
              MM
            </option>
            {Array.from({ length: 12 }, (_, index) => index + 1).map((month) => (
              <option value={month} key={month}>
                {String(month).padStart(2, "0")}
              </option>
            ))}
          </select>
          <FieldError errors={state.errors.exp_month} />
        </div>

        <div className="col-4">
          <label className="form-label" htmlFor="exp_year">
            Year
          </label>
          <select
            className="form-select"
            id="exp_year"
            name="exp_year"
            autoComplete="cc-exp-year"
            required
            defaultValue=""
          >
            <option value="" disabled>
              YYYY
            </option>
            {Array.from({ length: 15 }, (_, index) => currentYear + index).map(
              (year) => (
                <option value={year} key={year}>
                  {year}
                </option>
              ),
            )}
          </select>
          <FieldError errors={state.errors.exp_year} />
        </div>

        <div className="col-4">
          <label className="form-label" htmlFor="security_code">
            CVC
          </label>
          <input
            className="form-control"
            id="security_code"
            name="security_code"
            inputMode="numeric"
            autoComplete="cc-csc"
            placeholder="123"
            required
            value={securityCode}
            onChange={(event) =>
              setSecurityCode(event.target.value.replace(/\D/g, "").slice(0, 3))
            }
          />
          <FieldError errors={state.errors.security_code} />
        </div>
      </div>

      <div className="form-check mb-4">
        <input
          className="form-check-input"
          type="checkbox"
          id="is_default"
          name="is_default"
        />
        <label className="form-check-label" htmlFor="is_default">
          Use this card by default
        </label>
      </div>

      <button
        className="btn signin-submit-button w-100 py-2"
        type="submit"
        disabled={pending}
      >
        {pending ? "Saving..." : "Save card"}
      </button>
    </form>
  );
}
