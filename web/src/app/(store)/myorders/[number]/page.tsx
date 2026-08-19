import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { OrderStatusBadge } from "@/components/order-status-badge";
import { getCurrentUser } from "@/lib/auth";
import { formatPrice } from "@/lib/catalog";
import { fetchOrder } from "@/lib/orders";

import { OrderActions } from "./order-actions";

type OrderPageProps = {
  params: Promise<{ number: string }>;
  searchParams: Promise<{ placed?: string }>;
};

export async function generateMetadata({ params }: OrderPageProps) {
  const { number } = await params;
  return { title: `Order ${number}` } satisfies Metadata;
}

function formatMoment(value: string): string {
  return new Date(value).toLocaleString("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default async function OrderPage({
  params,
  searchParams,
}: OrderPageProps) {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  const { number } = await params;
  const { placed } = await searchParams;
  const order = await fetchOrder(number);

  // The API only returns the shopper's own orders, so a missing result
  // means either no such order or it belongs to someone else.
  if (!order) {
    notFound();
  }

  // Only the moments that happened, in the order they happened.
  const timeline = [
    { label: "Placed", at: order.created_at },
    { label: "Paid", at: order.paid_at },
    { label: "Shipped", at: order.shipped_at },
    { label: "Delivered", at: order.delivered_at },
    { label: "Cancelled", at: order.cancelled_at },
  ].filter((step) => step.at);

  return (
    <main className="container py-4" style={{ maxWidth: "900px" }}>
      <nav aria-label="Breadcrumb" className="product-breadcrumb mb-3">
        <Link href="/myorders">My Orders</Link>
        <span aria-hidden="true"> / </span>
        <span>{order.order_number}</span>
      </nav>

      {placed ? (
        <div className="order-placed" role="status">
          <strong>Thanks — your order is in.</strong>
          <span>
            {formatPrice(order.total)} was charged to your{" "}
            {order.card_brand} ending {order.card_last4}.
          </span>
        </div>
      ) : null}

      <div className="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
        <h1 className="section-title mb-0">{order.order_number}</h1>
        <OrderStatusBadge order={order} />
      </div>

      {order.last_payment_error ? (
        <div className="alert alert-danger" role="alert">
          <strong>This order has not been paid for.</strong>{" "}
          {order.last_payment_error} Nothing was charged and your stock was not
          reserved. <Link href="/cart">Start again from the cart</Link> with a
          different card.
        </div>
      ) : null}

      <div className="row g-4 align-items-start">
        <div className="col-12 col-lg-8">
          <section className="checkout-section mb-3">
            <h2 className="checkout-section-title">Items</h2>

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
                    {/* The product may be gone; the link then 404s, which
                        is why the name comes from the copy, not the link. */}
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
                      {item.seller_name ? ` · ${item.seller_name}` : ""}
                    </span>
                    {item.is_shipped ? (
                      <span className="order-line-shipped">Shipped</span>
                    ) : null}
                  </div>

                  <div className="cart-line-total">
                    {formatPrice(item.line_total)}
                  </div>
                </li>
              ))}
            </ul>
          </section>

          <section className="checkout-section">
            <h2 className="checkout-section-title">Progress</h2>
            <ol className="list-unstyled order-timeline mb-0">
              {timeline.map((step) => (
                <li key={step.label}>
                  <strong>{step.label}</strong>
                  <span>{formatMoment(step.at as string)}</span>
                </li>
              ))}
            </ol>
          </section>
        </div>

        <div className="col-12 col-lg-4">
          <aside className="cart-summary">
            <h2 className="h6 mb-3">Summary</h2>

            <div className="cart-summary-row">
              <span>Items ({order.item_count})</span>
              <span>{formatPrice(order.subtotal)}</span>
            </div>
            <div className="cart-summary-row">
              <span>Delivery</span>
              <span className={Number(order.shipping) === 0 ? "checkout-free" : undefined}>
                {Number(order.shipping) === 0
                  ? "Free"
                  : formatPrice(order.shipping)}
              </span>
            </div>

            <hr />

            <div className="cart-summary-row total">
              <span>Total</span>
              <span>{formatPrice(order.total)}</span>
            </div>

            <dl className="order-facts mt-3 mb-0">
              <div>
                <dt>Ships to</dt>
                <dd>
                  {order.recipient_name}
                  <br />
                  {order.address_line_1}
                  {order.address_line_2 ? `, ${order.address_line_2}` : ""}
                  <br />
                  {order.district}, {order.city} {order.postal_code}
                </dd>
              </div>
              <div>
                <dt>Paid with</dt>
                <dd>
                  {order.card_brand} ···· {order.card_last4}
                  <br />
                  Single payment
                </dd>
              </div>
            </dl>

            <OrderActions order={order} />
          </aside>
        </div>
      </div>
    </main>
  );
}
