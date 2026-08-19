import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth";
import { fetchAddresses } from "@/lib/addresses";
import { fetchCart } from "@/lib/cart";
import { fetchPaymentMethods } from "@/lib/payments";

import { CheckoutForm } from "./checkout-form";

export const metadata: Metadata = {
  title: "Checkout",
};

export default async function CheckoutPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  const [cart, addresses, cards] = await Promise.all([
    fetchCart(),
    fetchAddresses(),
    fetchPaymentMethods(),
  ]);

  // Nothing to check out; the cart page already explains what to do.
  if (!cart.items.length) {
    redirect("/cart");
  }

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-3">
        <h1 className="section-title mb-0">Checkout</h1>
        <Link className="btn btn-link p-0" href="/cart">
          Back to cart
        </Link>
      </div>

      {cart.has_stock_issues ? (
        <div className="alert alert-warning" role="alert">
          Some items are no longer available in the quantity you chose.{" "}
          <Link href="/cart">Adjust them</Link> before checking out.
        </div>
      ) : null}

      <CheckoutForm cart={cart} addresses={addresses} cards={cards} />
    </main>
  );
}
