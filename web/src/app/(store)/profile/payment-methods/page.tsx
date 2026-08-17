import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { CardBrandLogo } from "@/components/card-brand-logo";
import { getCurrentUser } from "@/lib/auth";
import { fetchPaymentMethods, formatExpiry } from "@/lib/payments";

import { AddCardForm } from "./add-card-form";
import { deletePaymentMethod, selectPaymentMethod } from "./actions";

export const metadata: Metadata = {
  title: "Payment methods",
};

export default async function PaymentMethodsPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  const methods = await fetchPaymentMethods();

  return (
    <main className="container py-4" style={{ maxWidth: "720px" }}>
      <h1 className="section-title mb-3">Payment methods</h1>

      <div className="profile-card p-4 mb-4">
        <h2 className="h6 mb-3">Saved cards</h2>

        {methods.length ? (
          <ul className="list-unstyled mb-0 payment-card-list">
            {methods.map((method) => (
              <li className="payment-card" key={method.id}>
                <div className="payment-card-main">
                  <CardBrandLogo brand={method.brand} />
                  <div className="payment-card-copy">
                    <strong>
                      {method.brand_display} ···· {method.last4}
                    </strong>
                    <span>
                      {method.holder_name} · Expires {formatExpiry(method)}
                    </span>
                  </div>
                </div>

                <div className="payment-card-actions">
                  {method.is_expired ? (
                    <span className="stock-badge out">Expired</span>
                  ) : method.is_default ? (
                    <span className="stock-badge">Default</span>
                  ) : (
                    <form action={selectPaymentMethod}>
                      <input type="hidden" name="id" value={method.id} />
                      <button className="btn btn-sm btn-outline-secondary" type="submit">
                        Make default
                      </button>
                    </form>
                  )}

                  <form action={deletePaymentMethod}>
                    <input type="hidden" name="id" value={method.id} />
                    <button className="btn btn-sm btn-outline-danger" type="submit">
                      Remove
                    </button>
                  </form>
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mb-0" style={{ color: "var(--site-muted-text)" }}>
            No cards saved yet.
          </p>
        )}
      </div>

      <div className="profile-card p-4">
        <h2 className="h6 mb-3">Add a card</h2>
        <AddCardForm />

        <p className="payment-security-note mt-3 mb-0">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            fill="currentColor"
            viewBox="0 0 16 16"
            aria-hidden="true"
          >
            <path d="M8 1a2 2 0 0 1 2 2v4H6V3a2 2 0 0 1 2-2m3 6V3a3 3 0 0 0-6 0v4a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2" />
          </svg>
          Your card number is never stored. Only the brand, the last four
          digits and the expiry are kept, alongside a token used for charges.
        </p>
      </div>
    </main>
  );
}
