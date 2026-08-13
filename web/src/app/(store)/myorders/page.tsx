import type { Metadata } from "next";

import { EmptyState, ReceiptIcon } from "@/components/empty-state";

export const metadata: Metadata = {
  title: "My Orders",
};

export default function MyOrdersPage() {
  return (
    <main className="container py-4">
      <h1 className="section-title mb-3">My Orders</h1>

      {/* TODO: render real orders once the order API is ready */}
      <EmptyState icon={<ReceiptIcon />} message="You have no orders yet." />
    </main>
  );
}
