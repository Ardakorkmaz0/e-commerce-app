"use client";

import Link from "next/link";
import { useActionState } from "react";

import { updateProfile, type EditProfileFormState } from "./actions";

const initialState: EditProfileFormState = {
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

type EditProfileFormProps = {
  defaultValues: {
    email: string;
    firstName: string;
    lastName: string;
  };
};

export function EditProfileForm({ defaultValues }: EditProfileFormProps) {
  const [state, formAction, pending] = useActionState(updateProfile, initialState);

  return (
    <form action={formAction} className="profile-form">
      {state.success ? (
        <div className="alert alert-success" role="status">
          Profile updated successfully.
        </div>
      ) : null}

      {state.message ? (
        <div className="alert alert-danger" role="alert" aria-live="polite">
          {state.message}
        </div>
      ) : null}

      <div className="row g-2">
        <div className="col-sm-6">
          <label className="form-label" htmlFor="firstName">
            First name
          </label>
          <input
            type="text"
            className="form-control"
            id="firstName"
            name="first_name"
            autoComplete="given-name"
            maxLength={150}
            defaultValue={defaultValues.firstName}
          />
          <FieldError errors={state.errors.first_name} />
        </div>

        <div className="col-sm-6">
          <label className="form-label" htmlFor="lastName">
            Last name
          </label>
          <input
            type="text"
            className="form-control"
            id="lastName"
            name="last_name"
            autoComplete="family-name"
            maxLength={150}
            defaultValue={defaultValues.lastName}
          />
          <FieldError errors={state.errors.last_name} />
        </div>
      </div>

      <div className="mt-3">
        <label className="form-label" htmlFor="email">
          Email
        </label>
        <input
          type="email"
          className="form-control"
          id="email"
          name="email"
          autoComplete="email"
          maxLength={254}
          required
          defaultValue={defaultValues.email}
        />
        <FieldError errors={state.errors.email} />
      </div>

      <div className="d-flex gap-2 mt-4">
        <Link className="btn btn-outline-secondary" href="/profile">
          Back
        </Link>
        <button
          className="btn signin-submit-button flex-grow-1"
          type="submit"
          disabled={pending}
        >
          {pending ? "Saving..." : "Save Changes"}
        </button>
      </div>
    </form>
  );
}
