import type { Metadata } from "next";
import Link from "next/link";

import { fetchAddresses } from "@/lib/addresses";

import { AddressCardActions } from "./address-card-actions";

export const metadata: Metadata = {
  title: "Addresses",
};

export default async function AddressesPage() {
  const addresses = await fetchAddresses();

  return (
    <main className="container py-4 address-book-page">
      <div className="address-book-header">
        <div>
          <Link className="address-back-link" href="/profile">
            &larr; Back to profile
          </Link>
          <h1>Addresses</h1>
          <p>Manage where your orders are delivered.</p>
        </div>
        <Link className="btn btn-primary" href="/profile/addresses/new">
          Add Address
        </Link>
      </div>

      {addresses.length ? (
        <div className="address-book-grid">
          {addresses.map((address) => {
            const locality = [address.postal_code, address.district, address.city]
              .filter(Boolean)
              .join(" ");

            return (
              <article
                className={`address-book-card ${address.is_default ? "selected" : ""}`}
                key={address.id}
              >
                <div className="address-book-card-heading">
                  <div>
                    <h2>{address.label}</h2>
                    {address.is_default ? (
                      <span className="address-default-badge">Selected</span>
                    ) : null}
                  </div>
                  <Link
                    className="address-edit-link"
                    href={`/profile/addresses/${address.id}/edit`}
                    aria-label={`Edit ${address.label}`}
                  >
                    Edit
                  </Link>
                </div>

                <strong className="address-recipient">{address.recipient_name}</strong>
                <address>
                  {address.address_line_1}
                  {address.address_line_2 ? <><br />{address.address_line_2}</> : null}
                  {locality ? <><br />{locality}</> : null}
                  <br />{address.country_code}
                </address>
                <span className="address-phone">{address.phone_number}</span>

                <AddressCardActions
                  addressId={address.id}
                  isSelected={address.is_default}
                />
              </article>
            );
          })}
        </div>
      ) : (
        <div className="profile-card address-book-empty">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="42"
            height="42"
            fill="currentColor"
            viewBox="0 0 16 16"
            aria-hidden="true"
          >
            <path d="M12.166 8.94c-.57 1.166-1.755 2.587-2.722 3.704C8.46 13.78 8 14.5 8 14.5s-.46-.72-1.444-1.856c-.967-1.117-2.152-2.538-2.722-3.704C3.287 7.82 3 6.742 3 5.75a5 5 0 0 1 10 0c0 .992-.287 2.07-.834 3.19M8 8a2.25 2.25 0 1 0 0-4.5A2.25 2.25 0 0 0 8 8" />
          </svg>
          <h2>No saved addresses</h2>
          <p>Add your first address to choose a delivery destination.</p>
          <Link className="btn btn-primary" href="/profile/addresses/new">
            Add your first address
          </Link>
        </div>
      )}
    </main>
  );
}
