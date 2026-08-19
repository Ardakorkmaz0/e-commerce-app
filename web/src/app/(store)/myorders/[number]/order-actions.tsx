import type { Order } from "@/lib/orders";

import { cancelOrder, confirmDelivery } from "./actions";

/**
 * What the shopper can still do with this order.
 *
 * When cancelling is closed the reason is spelled out rather than left as
 * a dead button — one seller posting their parcel closes it for the whole
 * order, which is not obvious from the outside.
 */
export function OrderActions({ order }: { order: Order }) {
  const shippedAlready = order.items.some((item) => item.is_shipped);

  if (order.status === "shipped") {
    return (
      <form action={confirmDelivery} className="mt-3">
        <input type="hidden" name="order_number" value={order.order_number} />
        <button className="btn signin-submit-button w-100 py-2" type="submit">
          I have received this
        </button>
      </form>
    );
  }

  if (order.status === "paid" && order.is_cancellable) {
    return (
      <form action={cancelOrder} className="mt-3">
        <input type="hidden" name="order_number" value={order.order_number} />
        <button className="btn btn-outline-danger w-100" type="submit">
          Cancel this order
        </button>
      </form>
    );
  }

  if (order.status === "paid" && shippedAlready) {
    return (
      <p className="checkout-nudge mb-0 mt-3">
        Part of this order has already been shipped, so it can no longer be
        cancelled.
      </p>
    );
  }

  return null;
}
