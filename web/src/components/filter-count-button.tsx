"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Submit button for the mobile filter form that keeps its count live.
 *
 * Only this button is a Client Component; the form around it stays server
 * rendered. It reads its own enclosing form on every change, asks the
 * catalog route how many products those values would match, and relabels
 * itself — so the shopper sees the effect before committing to it.
 */
export function FilterCountButton({ initialCount }: { initialCount: number }) {
  const buttonRef = useRef<HTMLButtonElement>(null);
  const [count, setCount] = useState(initialCount);
  const [pending, setPending] = useState(false);

  // A new server render means the filters were applied, so trust its number
  // again. Adjusted during render rather than in an effect: React re-runs
  // this component immediately, without the extra paint an effect costs.
  const [appliedCount, setAppliedCount] = useState(initialCount);
  if (initialCount !== appliedCount) {
    setAppliedCount(initialCount);
    setCount(initialCount);
  }

  useEffect(() => {
    const form = buttonRef.current?.form;
    if (!form) {
      return;
    }

    let timer: ReturnType<typeof setTimeout>;
    let controller: AbortController | null = null;

    const handleChange = () => {
      // Debounced: ticking three boxes quickly should cost one request.
      clearTimeout(timer);
      timer = setTimeout(() => {
        controller?.abort();
        controller = new AbortController();

        const params = new URLSearchParams();
        for (const [key, value] of new FormData(form).entries()) {
          const text = String(value);
          // Radios carry "" for "All"; sending it back would be noise.
          if (text) {
            params.append(key, text);
          }
        }

        setPending(true);
        fetch(`/api/catalog/products?${params.toString()}`, {
          signal: controller.signal,
        })
          .then((response) => (response.ok ? response.json() : null))
          .then((payload) => {
            if (payload && typeof payload.count === "number") {
              setCount(payload.count);
            }
          })
          .catch(() => {
            // Aborted or offline: keep the last number rather than lying.
          })
          .finally(() => setPending(false));
      }, 250);
    };

    form.addEventListener("change", handleChange);
    return () => {
      clearTimeout(timer);
      controller?.abort();
      form.removeEventListener("change", handleChange);
    };
  }, []);

  return (
    <button
      ref={buttonRef}
      className="btn signin-submit-button flex-grow-1"
      type="submit"
      // Not disabled while counting: the shopper can still apply.
      aria-busy={pending}
    >
      {pending ? "Counting…" : `Show ${count} product${count === 1 ? "" : "s"}`}
    </button>
  );
}
