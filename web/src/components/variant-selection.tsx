"use client";

import { createContext, useContext, useMemo, useState } from "react";

import type { OptionGroup, ProductVariant } from "@/lib/catalog";

type VariantSelectionValue = {
  groups: OptionGroup[];
  variants: ProductVariant[];
  /** Group slug to chosen value id. */
  selection: Record<string, number>;
  choose: (groupSlug: string, valueId: number) => void;
  /** Null while the shopper is on a combination that was never built. */
  variant: ProductVariant | null;
};

const VariantSelectionContext = createContext<VariantSelectionValue | null>(
  null,
);

/** A selection matches a variant when the two sets of value ids are equal. */
export function findVariant(
  variants: ProductVariant[],
  selection: Record<string, number>,
): ProductVariant | null {
  const chosen = Object.values(selection).sort((a, b) => a - b);
  return (
    variants.find(
      (variant) =>
        variant.option_value_ids.length === chosen.length &&
        variant.option_value_ids.every((id, index) => id === chosen[index]),
    ) ?? null
  );
}

/**
 * Holds which variant is being looked at.
 *
 * The picture sits in one column of the page and the picker in the other,
 * with server-rendered markup in between, so the selection cannot live
 * inside either of them. The provider wraps both and passes the rest of
 * the page through untouched as children.
 */
export function VariantSelectionProvider({
  groups,
  variants,
  children,
}: {
  groups: OptionGroup[];
  variants: ProductVariant[];
  children: React.ReactNode;
}) {
  // Start on the first combination that can actually be bought, so the page
  // opens showing a real price rather than an empty picker.
  const [selection, setSelection] = useState<Record<string, number>>(() => {
    const first = variants.find((variant) => variant.in_stock) ?? variants[0];
    if (!first) return {};

    const initial: Record<string, number> = {};
    for (const group of groups) {
      const match = group.values.find((value) =>
        first.option_value_ids.includes(value.id),
      );
      if (match) initial[group.slug] = match.id;
    }
    return initial;
  });

  const value = useMemo<VariantSelectionValue>(
    () => ({
      groups,
      variants,
      selection,
      choose: (groupSlug, valueId) =>
        setSelection((current) => ({ ...current, [groupSlug]: valueId })),
      variant: findVariant(variants, selection),
    }),
    [groups, variants, selection],
  );

  return (
    <VariantSelectionContext.Provider value={value}>
      {children}
    </VariantSelectionContext.Provider>
  );
}

export function useVariantSelection(): VariantSelectionValue {
  const value = useContext(VariantSelectionContext);
  if (!value) {
    throw new Error(
      "useVariantSelection must be used inside a VariantSelectionProvider",
    );
  }
  return value;
}
