import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { EmptyState, ReceiptIcon } from "@/components/empty-state";
import { OrderStatusBadge } from "@/components/order-status-badge";
import { getCurrentUser } from "@/lib/auth";
import { formatPrice } from "@/lib/catalog";
import { fetchOrders } from "@/lib/orders";

export const metadata: Metadata = {
  title: "My Orders",
};

/** "19 August 2026" — the date is all an order list needs. */
function formatDate(value: string): string {
  return new Date(value).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export default async function MyOrdersPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  const orders = await fetchOrders();

  return (
    <main className="container py-4">
      <h1 className="section-title mb-3">My Orders</h1>

      {orders.length ? (
        <ul className="list-unstyled order-list mb-0">
          {orders.map((order) => (
            <li className="order-card" key={order.id}>
              <div className="order-card-head">
                <div>
                  <span className="order-card-label">Order placed</span>
                  <strong>{formatDate(order.created_at)}</strong>
                </div>
                <div>
                  <span className="order-card-label">Total</span>
                  <strong>{formatPrice(order.total)}</strong>
                </div>
                <div>
                  <span className="order-card-label">Order</span>
                  <strong className="order-card-number">
                    {order.order_number}
                  </strong>
                </div>
                <OrderStatusBadge order={order} />
              </div>

              <div className="order-card-body">
                <ul className="list-unstyled order-thumbs mb-0">
                  {order.items.slice(0, 4).map((item) => (
                    <li key={item.id}>
                      {item.image_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={item.image_url} alt="" loading="lazy" />
                      ) : (
                        <span className="order-thumb-empty" />
                      )}
                    </li>
                  ))}
                  {order.items.length > 4 ? (
                    <li className="order-thumb-more">
                      +{order.items.length - 4}
                    </li>
                  ) : null}
                </ul>

                <div className="order-card-names">
                  {order.items
                    .slice(0, 2)
                    .map((item) => item.name)
                    .join(", ")}
                  {order.items.length > 2
                    ? ` and ${order.items.length - 2} more`
                    : ""}
                </div>

                <Link
                  className="btn btn-sm btn-outline-secondary"
                  href={`/myorders/${order.order_number}`}
                >
                  View order
                </Link>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <EmptyState icon={<ReceiptIcon />} message="You have no orders yet." />
      )}
    </main>
  );
}
