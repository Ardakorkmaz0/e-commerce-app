"use client";

import { formatPrice } from "@/lib/catalog";

import { useVariantSelection } from "./variant-selection";

/**
 * The headline price and stock badge for the chosen variant.
 *
 * A range was showing here while the picker printed the exact price a few
 * lines below, so the same product quoted two different numbers. There is
 * one price now, in the prominent spot, and it follows the selection.
 */
export function VariantPrice() {
  const { variant } = useVariantSelection();

  return (
    <div className="d-flex align-items-center gap-3 flex-wrap mb-3">
      <span className="product-detail-price">
        {variant ? formatPrice(variant.price) : "Choose an option"}
      </span>

      {!variant ? (
        <span className="stock-badge out">Unavailable combination</span>
      ) : variant.in_stock ? (
        <span className="stock-badge">In stock · {variant.stock} left</span>
      ) : (
        <span className="stock-badge out">Out of stock</span>
      )}
    </div>
  );
}
