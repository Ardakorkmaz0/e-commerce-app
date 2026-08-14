import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth";
import { fetchAttributes, fetchCategories } from "@/lib/products";

import { createProduct } from "../actions";
import { ProductForm } from "../product-form";

export const metadata: Metadata = {
  title: "Add Product",
};

export default async function NewProductPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }
  if (!user.is_seller) {
    redirect("/");
  }

  const [categories, attributes] = await Promise.all([
    fetchCategories(),
    fetchAttributes(),
  ]);

  return (
    <main className="container py-4" style={{ maxWidth: "720px" }}>
      <h1 className="section-title mb-3">Add Product</h1>
      <div className="profile-card p-4">
        <ProductForm
          action={createProduct}
          categories={categories}
          attributes={attributes}
          submitLabel="Create product"
        />
      </div>
    </main>
  );
}
