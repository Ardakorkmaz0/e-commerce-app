"use client";

import Link from "next/link";
import { useActionState } from "react";

import type { Address } from "@/lib/addresses";

import {
  createAddress,
  updateAddress,
  type AddressFormState,
} from "./actions";

const initialState: AddressFormState = {
  errors: {},
  message: "",
  success: false,
};

type FieldErrorProps = {
  errors?: string[];
};

function FieldError({ errors }: FieldErrorProps) {
  if (!errors?.length) {
    return null;
  }

  return (
    <div className="invalid-feedback d-block" role="alert">
      {errors.join(" ")}
    </div>
  );
}

type AddressFormProps = {
  address?: Address;
};

export function AddressForm({ address }: AddressFormProps) {
  const action = address ? updateAddress.bind(null, address.id) : createAddress;
  const [state, formAction, pending] = useActionState(action, initialState);

  return (
    <form action={formAction} className="address-form">
      {state.message ? (
        <div className="alert alert-danger" role="alert" aria-live="polite">
          {state.message}
        </div>
      ) : null}

      <FieldError errors={state.errors.non_field_errors} />

      <div className="row g-3">
        <div className="col-sm-5">
          <label className="form-label" htmlFor="addressLabel">
            Address label
          </label>
          <input
            className="form-control"
            id="addressLabel"
            name="label"
            type="text"
            maxLength={50}
            placeholder="Home or Work"
            defaultValue={address?.label ?? ""}
            required
          />
          <FieldError errors={state.errors.label} />
        </div>

        <div className="col-sm-7">
          <label className="form-label" htmlFor="recipientName">
            Recipient name
          </label>
          <input
            className="form-control"
            id="recipientName"
            name="recipient_name"
            type="text"
            autoComplete="name"
            maxLength={120}
            defaultValue={address?.recipient_name ?? ""}
            required
          />
          <FieldError errors={state.errors.recipient_name} />
        </div>

        <div className="col-12">
          <label className="form-label" htmlFor="phoneNumber">
            Phone number
          </label>
          <input
            className="form-control"
            id="phoneNumber"
            name="phone_number"
            type="tel"
            autoComplete="tel"
            maxLength={32}
            placeholder="+90 555 000 00 00"
            defaultValue={address?.phone_number ?? ""}
            required
          />
          <FieldError errors={state.errors.phone_number} />
        </div>

        <div className="col-12">
          <label className="form-label" htmlFor="addressLine1">
            Street address
          </label>
          <input
            className="form-control"
            id="addressLine1"
            name="address_line_1"
            type="text"
            autoComplete="address-line1"
            maxLength={200}
            placeholder="Street, building and apartment"
            defaultValue={address?.address_line_1 ?? ""}
            required
          />
          <FieldError errors={state.errors.address_line_1} />
        </div>

        <div className="col-12">
          <label className="form-label" htmlFor="addressLine2">
            Address details <span className="address-optional">Optional</span>
          </label>
          <input
            className="form-control"
            id="addressLine2"
            name="address_line_2"
            type="text"
            autoComplete="address-line2"
            maxLength={200}
            placeholder="Floor, entrance or delivery note"
            defaultValue={address?.address_line_2 ?? ""}
          />
          <FieldError errors={state.errors.address_line_2} />
        </div>

        <div className="col-sm-6">
          <label className="form-label" htmlFor="district">
            District
          </label>
          <input
            className="form-control"
            id="district"
            name="district"
            type="text"
            autoComplete="address-level2"
            maxLength={100}
            defaultValue={address?.district ?? ""}
            required
          />
          <FieldError errors={state.errors.district} />
        </div>

        <div className="col-sm-6">
          <label className="form-label" htmlFor="city">
            City
          </label>
          <input
            className="form-control"
            id="city"
            name="city"
            type="text"
            autoComplete="address-level1"
            maxLength={100}
            defaultValue={address?.city ?? ""}
            required
          />
          <FieldError errors={state.errors.city} />
        </div>

        <div className="col-sm-8">
          <label className="form-label" htmlFor="postalCode">
            Postal code <span className="address-optional">Optional</span>
          </label>
          <input
            className="form-control"
            id="postalCode"
            name="postal_code"
            type="text"
            autoComplete="postal-code"
            maxLength={20}
            defaultValue={address?.postal_code ?? ""}
          />
          <FieldError errors={state.errors.postal_code} />
        </div>

        <div className="col-sm-4">
          <label className="form-label" htmlFor="countryCode">
            Country code
          </label>
          <input
            className="form-control text-uppercase"
            id="countryCode"
            name="country_code"
            type="text"
            autoComplete="country"
            minLength={2}
            maxLength={2}
            pattern="[A-Za-z]{2}"
            title="Enter a two-letter country code"
            defaultValue={address?.country_code ?? "TR"}
            required
          />
          <FieldError errors={state.errors.country_code} />
        </div>
      </div>

      <div className="d-flex flex-column-reverse flex-sm-row gap-2 mt-4">
        <Link className="btn btn-outline-secondary" href="/profile/addresses">
          Cancel
        </Link>
        <button
          className="btn signin-submit-button flex-grow-1"
          type="submit"
          disabled={pending}
        >
          {pending ? "Saving..." : address ? "Save Address" : "Add Address"}
        </button>
      </div>
    </form>
  );
}
