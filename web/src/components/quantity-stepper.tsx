"use client";

import { useId } from "react";

type QuantityStepperProps = {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  /** Set to post the value with a surrounding form. */
  name?: string;
  disabled?: boolean;
  /** Shrinks it for the cart lines. */
  small?: boolean;
};

/**
 * A minus / number / plus pill.
 *
 * A bare `<input type="number">` leaves the shopper hunting for spinner
 * arrows that are a few pixels tall and absent on touch, so the two
 * buttons are the control and the box in the middle is still typeable for
 * anyone who wants to jump straight to 12.
 */
export function QuantityStepper({
  value,
  onChange,
  min = 1,
  max = 20,
  name,
  disabled = false,
  small = false,
}: QuantityStepperProps) {
  const id = useId();

  function clamp(next: number) {
    if (!Number.isFinite(next)) return min;
    return Math.min(Math.max(Math.round(next), min), max);
  }

  return (
    <div
      className={`quantity-stepper${small ? " small" : ""}${
        disabled ? " disabled" : ""
      }`}
    >
      <button
        type="button"
        className="quantity-step"
        aria-label="Decrease quantity"
        disabled={disabled || value <= min}
        onClick={() => onChange(clamp(value - 1))}
      >
        <svg width="14" height="14" viewBox="0 0 16 16" aria-hidden="true">
          <path d="M2 7.25h12v1.5H2z" fill="currentColor" />
        </svg>
      </button>

      <input
        id={id}
        className="quantity-value"
        type="number"
        inputMode="numeric"
        aria-label="Quantity"
        value={value}
        min={min}
        max={max}
        disabled={disabled}
        onChange={(event) => onChange(clamp(Number(event.target.value)))}
        // An empty box while typing must not post as 0.
        onBlur={(event) => onChange(clamp(Number(event.target.value)))}
      />

      <button
        type="button"
        className="quantity-step"
        aria-label="Increase quantity"
        disabled={disabled || value >= max}
        onClick={() => onChange(clamp(value + 1))}
      >
        <svg width="14" height="14" viewBox="0 0 16 16" aria-hidden="true">
          <path
            d="M7.25 2h1.5v5.25H14v1.5H8.75V14h-1.5V8.75H2v-1.5h5.25z"
            fill="currentColor"
          />
        </svg>
      </button>

      {/* The visible input is unnamed so the value posts exactly once. */}
      {name ? <input type="hidden" name={name} value={value} /> : null}
    </div>
  );
}
