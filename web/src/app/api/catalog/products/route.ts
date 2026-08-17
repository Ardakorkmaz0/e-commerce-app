import { NextRequest, NextResponse } from "next/server";

import { getApiBaseUrl } from "@/lib/auth";
import { PRODUCT_PAGE_SIZE, type PaginatedProducts } from "@/lib/catalog";

function positivePage(value: string | null): number {
  const page = Number.parseInt(value ?? "1", 10);
  return Number.isFinite(page) && page > 0 ? page : 1;
}

export async function GET(request: NextRequest) {
  const params = new URLSearchParams(request.nextUrl.searchParams);
  params.set("page", String(positivePage(params.get("page"))));
  params.set("page_size", String(PRODUCT_PAGE_SIZE));

  try {
    const response = await fetch(`${getApiBaseUrl()}/products/?${params}`, {
      cache: "no-store",
    });

    if (!response.ok) {
      return NextResponse.json(
        { detail: "The product catalog is temporarily unavailable." },
        { status: 502 },
      );
    }

    const payload = (await response.json()) as PaginatedProducts;
    return NextResponse.json(payload, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return NextResponse.json(
      { detail: "The product catalog is temporarily unavailable." },
      { status: 502 },
    );
  }
}
