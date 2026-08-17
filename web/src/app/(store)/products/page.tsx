import type { Metadata } from "next";

import {
  ProductCatalog,
  type CatalogSearchParams,
} from "@/components/product-catalog";

export const metadata: Metadata = {
  title: "Products",
};

type ProductsPageProps = {
  searchParams: Promise<CatalogSearchParams>;
};

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  return <ProductCatalog searchParams={await searchParams} />;
}
