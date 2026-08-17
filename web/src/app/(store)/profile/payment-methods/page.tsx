import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Payment Methods",
};

export default function PaymentMethodsPage() {
  return (
    <main className="container py-4 payment-methods-page">
      <Link className="address-back-link" href="/profile">
        &larr; Back to profile
      </Link>
      <div className="profile-card payment-methods-card">
        <div className="payment-methods-icon" aria-hidden="true">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="36"
            height="36"
            fill="currentColor"
            viewBox="0 0 16 16"
          >
            <path d="M0 4a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v1H0zm0 3v5a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7zm3 3h2a1 1 0 0 1 0 2H3a1 1 0 0 1 0-2" />
          </svg>
        </div>
        <span className="payment-coming-soon">Coming soon</span>
        <h1>Saved payment methods</h1>
        <p>
          Secure card storage will be available after the payment infrastructure
          is connected. No card information is collected or stored right now.
        </p>
        <button
          className="btn btn-primary"
          type="button"
          disabled
          title="Saved payment methods are coming soon"
        >
          Add payment method
        </button>
      </div>
    </main>
  );
}
