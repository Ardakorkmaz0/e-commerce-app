import type { Metadata } from "next";

import { AddressForm } from "../address-form";

export const metadata: Metadata = {
  title: "Add Address",
};

export default function NewAddressPage() {
  return (
    <main className="container py-4 address-form-page">
      <div className="profile-card p-4">
        <div className="address-form-heading">
          <span>Delivery details</span>
          <h1>Add a new address</h1>
          <p>Use an address where someone can receive your order.</p>
        </div>
        <AddressForm />
      </div>
    </main>
  );
}
