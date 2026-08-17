"use client";

import { useRouter } from "next/navigation";
import { useActionState } from "react";

import {
  selectAddress,
  type AddressActionState,
} from "@/app/(store)/profile/addresses/actions";
import type { Address } from "@/lib/addresses";

const initialState: AddressActionState = {
  message: "",
  success: false,
};

function AddressChoice({ address }: { address: Address }) {
  const action = selectAddress.bind(null, address.id);
  const [state, formAction, pending] = useActionState(action, initialState);
  const locality = [address.postal_code, address.district, address.city]
    .filter(Boolean)
    .join(" ");

  return (
    <article className={`address-choice ${address.is_default ? "selected" : ""}`}>
      <div className="address-choice-heading">
        <div>
          <strong>{address.label}</strong>
          {address.is_default ? <span className="address-default-badge">Selected</span> : null}
        </div>
        <span className="address-choice-recipient">{address.recipient_name}</span>
      </div>

      <p className="address-choice-lines">
        {address.address_line_1}
        {address.address_line_2 ? <><br />{address.address_line_2}</> : null}
        {locality ? <><br />{locality}</> : null}
        <br />{address.country_code}
      </p>

      {address.is_default ? (
        <span className="address-current-note">Current delivery address</span>
      ) : (
        <form action={formAction}>
          <button
            className="btn btn-sm btn-outline-primary"
            type="submit"
            disabled={pending}
          >
            {pending ? "Selecting..." : "Deliver here"}
          </button>
        </form>
      )}

      {state.message ? (
        <p
          className={`address-action-message ${state.success ? "success" : "error"}`}
          role={state.success ? "status" : "alert"}
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}
    </article>
  );
}

export function AddressSelector({ addresses }: { addresses: Address[] }) {
  const router = useRouter();

  return (
    <>
      <div className="address-selector-list">
        {addresses.length ? (
          addresses.map((address) => (
            <AddressChoice
              address={address}
              key={`${address.id}-${address.is_default ? "selected" : "saved"}`}
            />
          ))
        ) : (
          <div className="address-selector-empty">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="30"
              height="30"
              fill="currentColor"
              viewBox="0 0 16 16"
              aria-hidden="true"
            >
              <path d="M12.166 8.94c-.57 1.166-1.755 2.587-2.722 3.704C8.46 13.78 8 14.5 8 14.5s-.46-.72-1.444-1.856c-.967-1.117-2.152-2.538-2.722-3.704C3.287 7.82 3 6.742 3 5.75a5 5 0 0 1 10 0c0 .992-.287 2.07-.834 3.19M8 8a2.25 2.25 0 1 0 0-4.5A2.25 2.25 0 0 0 8 8" />
            </svg>
            <strong>No saved addresses</strong>
            <span>Add an address to choose where your orders are delivered.</span>
          </div>
        )}
      </div>

      {/* Buttons, not links: Bootstrap calls preventDefault() on dismiss
          triggers that are anchors, so the modal closed but the navigation
          never happened. A button is dismissed by Bootstrap and routed by
          the handler, so both actually run. */}
      <div className="address-selector-links">
        <button
          type="button"
          className="btn btn-primary"
          data-bs-dismiss="modal"
          onClick={() => router.push("/profile/addresses/new")}
        >
          Add a new address
        </button>
        {addresses.length ? (
          <button
            type="button"
            className="btn btn-link"
            data-bs-dismiss="modal"
            onClick={() => router.push("/profile/addresses")}
          >
            Manage addresses
          </button>
        ) : null}
      </div>
    </>
  );
}
