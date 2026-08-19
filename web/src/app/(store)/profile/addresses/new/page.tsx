import type { Metadata } from "next";
import Link from "next/link";

import { safeNext } from "@/lib/safe-next";

import { AddressForm } from "../address-form";

export const metadata: Metadata = {
  title: "Add Address",
};

type NewAddressPageProps = {
  searchParams: Promise<{ next?: string }>;
};

export default async function NewAddressPage({
  searchParams,
}: NewAddressPageProps) {
  const { next } = await searchParams;
  const returnTo = safeNext(next);

  return (
    <main className="container py-4 address-form-page">
      <div className="profile-card p-4">
        <div className="address-form-heading">
          <span>Delivery details</span>
          <h1>Add a new address</h1>
          <p>Use an address where someone can receive your order.</p>
        </div>

        {/* A way out that does not need the form filled in first. */}
        {returnTo === "/checkout" ? (
          <p className="checkout-nudge">
            Saving this takes you back to <Link href="/checkout">checkout</Link>.
          </p>
        ) : null}

        <AddressForm next={returnTo ?? undefined} />
      </div>
    </main>
  );
}
