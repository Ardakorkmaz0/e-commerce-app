import type { Metadata } from "next";

import { CartIcon, EmptyState } from "@/components/empty-state";

export const metadata: Metadata = {
  title: "Cart",
};

export default function CartPage() {
  return (
    <main className="container py-4">
      <h1 className="section-title mb-3">Cart</h1>

      {/* TODO: render real cart items once the cart API is ready */}
      <EmptyState icon={<CartIcon />} message="Your cart is empty." />
    </main>
  );
}
