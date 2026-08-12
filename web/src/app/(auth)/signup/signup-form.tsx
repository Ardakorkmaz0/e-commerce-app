"use client";

import Link from "next/link";
import { useActionState } from "react";

import { signUp, type SignUpFormState } from "./actions";

const initialSignUpState: SignUpFormState = {
  errors: {},
  message: "",
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

export function SignUpForm() {
  const [state, formAction, pending] = useActionState(signUp, initialSignUpState);

  return (
    <form action={formAction}>
      {state.message ? (
        <div className="alert alert-danger" role="alert" aria-live="polite">
          {state.message}
        </div>
      ) : null}

      <div className="form-floating signup-field">
        <input
          type="text"
          className="form-control"
          id="floatingUsername"
          name="username"
          placeholder="Username"
          autoComplete="username"
          maxLength={150}
          required
          autoFocus
        />
        <label htmlFor="floatingUsername">Username</label>
      </div>
      <FieldError errors={state.errors.username} />

      <div className="form-floating signup-field">
        <input
          type="email"
          className="form-control"
          id="floatingEmail"
          name="email"
          placeholder="Email"
          autoComplete="email"
          maxLength={254}
          required
        />
        <label htmlFor="floatingEmail">Email</label>
      </div>
      <FieldError errors={state.errors.email} />

      <div className="row g-2">
        <div className="col-sm-6">
          <div className="form-floating signup-field">
            <input
              type="text"
              className="form-control"
              id="floatingFirstName"
              name="first_name"
              placeholder="First name"
              autoComplete="given-name"
              maxLength={150}
            />
            <label htmlFor="floatingFirstName">First name</label>
          </div>
          <FieldError errors={state.errors.first_name} />
        </div>

        <div className="col-sm-6">
          <div className="form-floating signup-field">
            <input
              type="text"
              className="form-control"
              id="floatingLastName"
              name="last_name"
              placeholder="Last name"
              autoComplete="family-name"
              maxLength={150}
            />
            <label htmlFor="floatingLastName">Last name</label>
          </div>
          <FieldError errors={state.errors.last_name} />
        </div>
      </div>

      <div className="form-floating signup-field">
        <input
          type="password"
          className="form-control"
          id="floatingPassword"
          name="password"
          placeholder="Password"
          autoComplete="new-password"
          required
        />
        <label htmlFor="floatingPassword">Password</label>
      </div>
      <FieldError errors={state.errors.password} />

      <div className="form-floating signup-field">
        <input
          type="password"
          className="form-control"
          id="floatingPasswordConfirm"
          name="password_confirm"
          placeholder="Confirm password"
          autoComplete="new-password"
          required
        />
        <label htmlFor="floatingPasswordConfirm">Confirm password</label>
      </div>
      <FieldError errors={state.errors.password_confirm} />
      <FieldError errors={state.errors.non_field_errors} />

      <button
        className="btn signin-submit-button w-100 py-2 mt-3"
        type="submit"
        disabled={pending}
      >
        {pending ? "Creating account..." : "Sign Up"}
      </button>

      <div className="text-center mt-4">
        <span className="signin-signup-text">Already have an account?</span>
        <Link href="/signin" className="btn signin-signup-button">Sign in</Link>
      </div>
    </form>
  );
}
