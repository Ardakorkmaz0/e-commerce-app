"use client";

import Link from "next/link";
import { useActionState } from "react";

import { signIn, type SignInFormState } from "./actions";

const initialSignInState: SignInFormState = {
  message: "",
  username: "",
};

type SignInFormProps = {
  registered: boolean;
};

export function SignInForm({ registered }: SignInFormProps) {
  const [state, formAction, pending] = useActionState(signIn, initialSignInState);

  return (
    <form action={formAction}>
      {registered && !state.message ? (
        <div className="alert alert-success" role="status">
          Account created. You can sign in now.
        </div>
      ) : null}

      {state.message ? (
        <div className="alert alert-danger" role="alert" aria-live="polite">
          {state.message}
        </div>
      ) : null}

      <div className="form-floating">
        <input
          type="text"
          className="form-control"
          id="floatingUsername"
          name="username"
          placeholder="Username"
          autoComplete="username"
          defaultValue={state.username}
          required
          autoFocus
        />
        <label htmlFor="floatingUsername">Username</label>
      </div>

      <div className="form-floating">
        <input
          type="password"
          className="form-control"
          id="floatingPassword"
          name="password"
          placeholder="Password"
          autoComplete="current-password"
          required
        />
        <label htmlFor="floatingPassword">Password</label>
      </div>

      <div className="form-check text-start my-3">
        <input
          className="form-check-input"
          type="checkbox"
          name="remember_me"
          id="rememberMe"
        />
        <label className="form-check-label" htmlFor="rememberMe">
          Remember me
        </label>
      </div>

      <button
        className="btn signin-submit-button w-100 py-2"
        type="submit"
        disabled={pending}
      >
        {pending ? "Signing in..." : "Sign in"}
      </button>

      <div className="text-center mt-4">
        <span className="signin-signup-text">Don&apos;t have an account?</span>
        <Link href="/signup" className="btn signin-signup-button">
          Sign Up
        </Link>
      </div>
    </form>
  );
}
