import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Sign In",
};

export default function SignInPage() {
  return (
    <main className="signin-page d-flex align-items-center min-vh-100">
      <div className="form-signin w-100 m-auto">
        <form method="post">
          <Image
            className="signin-logo mb-4"
            src="/images/logo.png"
            alt="E-Commerce logo"
            width={160}
            height={160}
            priority
          />
          <h1 className="h3 mb-3 fw-normal text-center" />

          <div className="form-floating">
            <input
              type="text"
              className="form-control"
              id="floatingUsername"
              name="username"
              placeholder="Username"
              autoComplete="username"
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
            <input className="form-check-input" type="checkbox" name="remember_me" id="rememberMe" />
            <label className="form-check-label" htmlFor="rememberMe">Remember me</label>
          </div>

          <button className="btn signin-submit-button w-100 py-2" type="submit">Sign in</button>

          <div className="text-center mt-4">
            <span className="signin-signup-text">Don&apos;t have an account?</span>
            <Link href="/signup" className="btn signin-signup-button">Sign Up</Link>
          </div>

          <p className="mt-5 mb-3 text-body-secondary text-center">E-Commerce</p>
        </form>
      </div>
    </main>
  );
}
