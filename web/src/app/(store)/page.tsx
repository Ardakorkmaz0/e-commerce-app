import type { Metadata } from "next";

import {
  ProductCatalog,
  type CatalogSearchParams,
} from "@/components/product-catalog";

export const metadata: Metadata = {
  title: "Shop",
};

type HomePageProps = {
  searchParams: Promise<CatalogSearchParams>;
};

export default async function HomePage({ searchParams }: HomePageProps) {
  return <ProductCatalog searchParams={await searchParams} />;
}
