"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import { ProductCard } from "@/components/product-card";
import {
  PRODUCT_PAGE_SIZE,
  type PaginatedProducts,
  type Product,
} from "@/lib/catalog";

type InfiniteProductGridProps = {
  initialPage: PaginatedProducts;
  queryString: string;
  gridClassName: string;
};

export function InfiniteProductGrid({
  initialPage,
  queryString,
  gridClassName,
}: InfiniteProductGridProps) {
  const [products, setProducts] = useState(initialPage.results);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(Boolean(initialPage.next));
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const sentinelRef = useRef<HTMLDivElement>(null);
  const loadingRef = useRef(false);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    return () => abortRef.current?.abort();
  }, []);

  const loadMore = useCallback(async () => {
    if (!hasMore || loadingRef.current) return;

    loadingRef.current = true;
    setIsLoading(true);
    setError("");

    const nextPage = page + 1;
    const params = new URLSearchParams(queryString);
    params.set("page", String(nextPage));
    params.set("page_size", String(PRODUCT_PAGE_SIZE));

    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const response = await fetch(`/api/catalog/products?${params}`, {
        cache: "no-store",
        signal: controller.signal,
      });
      if (!response.ok) throw new Error("Catalog request failed");

      const nextBatch = (await response.json()) as PaginatedProducts;
      setProducts((current) => {
        const knownIds = new Set(current.map((product) => product.id));
        const uniqueProducts = nextBatch.results.filter(
          (product: Product) => !knownIds.has(product.id),
        );
        return [...current, ...uniqueProducts];
      });
      setPage(nextPage);
      setHasMore(Boolean(nextBatch.next));
    } catch (requestError) {
      if ((requestError as Error).name !== "AbortError") {
        setError("More products could not be loaded. Please try again.");
      }
    } finally {
      loadingRef.current = false;
      setIsLoading(false);
    }
  }, [hasMore, page, queryString]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasMore || error) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) void loadMore();
      },
      { rootMargin: "600px 0px" },
    );

    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [error, hasMore, loadMore]);

  return (
    <div aria-busy={isLoading}>
      <div className={gridClassName}>
        {products.map((product) => (
          <div className="col" key={product.id}>
            <ProductCard product={product} />
          </div>
        ))}

        {isLoading
          ? Array.from({ length: 4 }, (_, index) => (
              <div className="col" key={`loading-${index}`} aria-hidden="true">
                <div className="product-card product-card-skeleton">
                  <span className="product-skeleton-media" />
                  <span className="product-skeleton-line wide" />
                  <span className="product-skeleton-line" />
                  <span className="product-skeleton-line short" />
                </div>
              </div>
            ))
          : null}
      </div>

      <div className="catalog-loader" ref={sentinelRef}>
        {error ? <p className="catalog-load-error">{error}</p> : null}
        {hasMore ? (
          <button
            className="btn catalog-load-button"
            type="button"
            onClick={() => void loadMore()}
            disabled={isLoading}
          >
            {isLoading ? "Loading products..." : error ? "Try again" : "Load more"}
          </button>
        ) : products.length ? (
          <span className="catalog-load-complete">
            All {initialPage.count} products are loaded.
          </span>
        ) : null}
        <span className="visually-hidden" aria-live="polite">
          {isLoading
            ? "Loading more products"
            : `${products.length} of ${initialPage.count} products loaded`}
        </span>
      </div>
    </div>
  );
}
