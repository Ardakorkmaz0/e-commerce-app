import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { fetchAddress } from "@/lib/addresses";

import { AddressForm } from "../../address-form";

export const metadata: Metadata = {
  title: "Edit Address",
};

type EditAddressPageProps = {
  params: Promise<{ id: string }>;
};

export default async function EditAddressPage({ params }: EditAddressPageProps) {
  const { id } = await params;
  const addressId = Number(id);
  if (!Number.isInteger(addressId) || addressId <= 0) {
    notFound();
  }

  const address = await fetchAddress(addressId);
  if (!address) {
    notFound();
  }

  return (
    <main className="container py-4 address-form-page">
      <div className="profile-card p-4">
        <div className="address-form-heading">
          <span>Delivery details</span>
          <h1>Edit address</h1>
          <p>Update the details used for this delivery destination.</p>
        </div>
        <AddressForm address={address} />
      </div>
    </main>
  );
}
