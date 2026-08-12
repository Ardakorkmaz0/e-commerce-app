import type { Metadata } from "next";
import Image from "next/image";

import { SignUpForm } from "./signup-form";

export const metadata: Metadata = {
  title: "Sign Up",
};

export default function SignUpPage() {
  return (
    <main className="signin-page d-flex align-items-center min-vh-100">
      <div className="form-signin signup-form w-100 m-auto">
        <Image
          className="signin-logo mb-4"
          src="/images/logo.png"
          alt="E-Commerce logo"
          width={160}
          height={160}
          priority
        />
        <h1 className="h3 mb-4 fw-normal text-center">Create account</h1>
        <SignUpForm />
        <p className="mt-5 mb-3 text-body-secondary text-center">E-Commerce</p>
      </div>
    </main>
  );
}
