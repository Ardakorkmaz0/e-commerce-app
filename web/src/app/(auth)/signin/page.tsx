import type { Metadata } from "next";
import Image from "next/image";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth";

import { SignInForm } from "./signin-form";

export const metadata: Metadata = {
  title: "Sign In",
};

type SignInPageProps = {
  searchParams: Promise<{ registered?: string }>;
};

export default async function SignInPage({ searchParams }: SignInPageProps) {
  const user = await getCurrentUser();
  if (user) {
    redirect("/");
  }

  const { registered } = await searchParams;

  return (
    <main className="signin-page d-flex align-items-center min-vh-100">
      <div className="form-signin w-100 m-auto">
        <Image
          className="signin-logo mb-4"
          src="/images/logo.png"
          alt="E-Commerce logo"
          width={160}
          height={160}
          priority
        />
        <h1 className="h3 mb-3 fw-normal text-center" />
        <SignInForm registered={registered === "1"} />
        <p className="mt-5 mb-3 text-body-secondary text-center">E-Commerce</p>
      </div>
    </main>
  );
}
