import type { Order, SellerOrder } from "@/lib/orders";
import { statusTone } from "@/lib/orders";

/**
 * The status pill.
 *
 * Takes the whole order rather than the status alone so a pending one can
 * say *why* it is pending — "Payment declined" is what the shopper needs
 * to read, not the word "pending".
 */
export function OrderStatusBadge({
  order,
}: {
  order: Pick<Order, "status" | "status_display"> &
    Partial<Pick<Order, "last_payment_error">>;
}) {
  const unpaid = order.status === "pending" && order.last_payment_error;

  return (
    <span className={`order-status ${statusTone(order.status)}`}>
      {unpaid ? "Payment failed" : order.status_display}
    </span>
  );
}

export function SellerOrderStatusBadge({ order }: { order: SellerOrder }) {
  return (
    <span className={`order-status ${statusTone(order.status)}`}>
      {order.status_display}
    </span>
  );
}
