import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { EmptyState, ReceiptIcon } from "@/components/empty-state";
import { SellerOrderStatusBadge } from "@/components/order-status-badge";
import { getCurrentUser } from "@/lib/auth";
import { formatPrice } from "@/lib/catalog";
import { fetchSellerOrders } from "@/lib/orders";

import { shipOrder } from "./actions";

export const metadata: Metadata = {
  title: "Orders",
};

function formatDate(value: string): string {
  return new Date(value).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export default async function SellerOrdersPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }
  if (!user.is_seller) {
    redirect("/");
  }

  const orders = await fetchSellerOrders();
  const toPack = orders.filter(
    (order) =>
      order.status !== "cancelled" &&
      order.items.some((item) => !item.shipped_at),
  );

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-baseline justify-content-between gap-2 mb-3">
        <h1 className="section-title mb-0">Orders</h1>
        <span style={{ color: "var(--site-muted-text)" }}>
          {toPack.length
            ? `${toPack.length} waiting to be shipped`
            : "Nothing waiting"}
        </span>
      </div>

      <p className="mb-4" style={{ color: "var(--site-muted-text)" }}>
        Only your own lines are shown. An order may also contain items from
        other sellers, which they post themselves.
      </p>

      {orders.length ? (
        <ul className="list-unstyled order-list mb-0">
          {orders.map((order) => {
            const pending = order.items.filter((item) => !item.shipped_at);

            return (
              <li className="order-card" key={order.id}>
                <div className="order-card-head">
                  <div>
                    <span className="order-card-label">Placed</span>
                    <strong>{formatDate(order.created_at)}</strong>
                  </div>
                  <div>
                    <span className="order-card-label">Your total</span>
                    <strong>{formatPrice(order.seller_total)}</strong>
                  </div>
                  <div>
                    <span className="order-card-label">Order</span>
                    <strong className="order-card-number">
                      {order.order_number}
                    </strong>
                  </div>
                  <SellerOrderStatusBadge order={order} />
                </div>

                <div className="seller-order-body">
                  <ul className="list-unstyled checkout-items mb-0">
                    {order.items.map((item) => (
                      <li className="checkout-item" key={item.id}>
                        <div className="checkout-item-media">
                          {item.image_url ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img src={item.image_url} alt="" loading="lazy" />
                          ) : (
                            <span className="checkout-item-placeholder" />
                          )}
                        </div>
                        <div className="checkout-item-body">
                          <Link
                            className="checkout-item-name"
                            href={`/products/${item.slug}`}
                          >
                            {item.name}
                          </Link>
                          {item.option_label ? (
                            <span className="cart-line-option">
                              {item.option_label}
                            </span>
                          ) : null}
                          <span className="checkout-item-meta">
                            {formatPrice(item.unit_price)} × {item.quantity}
                          </span>
                          {item.shipped_at ? (
                            <span className="order-line-shipped">Shipped</span>
                          ) : null}
                        </div>
                        <div className="cart-line-total">
                          {formatPrice(item.line_total)}
                        </div>
                      </li>
                    ))}
                  </ul>

                  {/* Enough to post a parcel, and nothing about the
                      account behind it. */}
                  <div className="seller-order-address">
                    <span className="order-card-label">Ship to</span>
                    <address className="mb-0">
                      {order.recipient_name}
                      <br />
                      {order.phone_number}
                      <br />
                      {order.address_line_1}
                      {order.address_line_2 ? `, ${order.address_line_2}` : ""}
                      <br />
                      {order.district}, {order.city} {order.postal_code}
                    </address>

                    {order.status === "cancelled" ? (
                      <p className="checkout-nudge mb-0">
                        Cancelled by the customer.
                      </p>
                    ) : pending.length ? (
                      <form action={shipOrder} className="mt-2">
                        <input
                          type="hidden"
                          name="order_number"
                          value={order.order_number}
                        />
                        <button
                          className="btn btn-sm signin-submit-button"
                          type="submit"
                        >
                          Mark as shipped
                        </button>
                      </form>
                    ) : (
                      <p className="checkout-nudge mb-0">
                        Your parcel has gone out.
                      </p>
                    )}
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      ) : (
        <EmptyState
          icon={<ReceiptIcon />}
          message="Nobody has bought anything from you yet."
        />
      )}
    </main>
  );
}
