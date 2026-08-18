import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth";
import { fetchAttributes, fetchCategories } from "@/lib/products";
import { fetchSellerProduct, fetchSellerVariants } from "@/lib/seller";

import { updateProduct } from "../../actions";
import { ProductForm } from "../../product-form";
import { VariantSection } from "../variants/variant-section";

export const metadata: Metadata = {
  title: "Edit Product",
};

type EditProductPageProps = {
  params: Promise<{ slug: string }>;
};

export default async function EditProductPage({ params }: EditProductPageProps) {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }
  if (!user.is_seller) {
    redirect("/");
  }

  const { slug } = await params;

  const [product, categories, attributes, variants] = await Promise.all([
    fetchSellerProduct(slug),
    fetchCategories(),
    fetchAttributes(),
    fetchSellerVariants(slug),
  ]);

  // The API only returns the seller's own products, so a missing result
  // means either no such product or it belongs to someone else.
  if (!product) {
    notFound();
  }

  // Server Actions cannot take extra arguments from the client, so the slug
  // is bound here on the server before the action reaches the form.
  const updateWithSlug = updateProduct.bind(null, product.slug);

  return (
    <main className="container py-4" style={{ maxWidth: "860px" }}>
      <h1 className="section-title mb-3">Edit Product</h1>
      <div className="profile-card p-4">
        <ProductForm
          action={updateWithSlug}
          categories={categories}
          attributes={attributes}
          submitLabel="Save changes"
          defaults={{
            name: product.name,
            description: product.description,
            price: product.price,
            stock: product.stock,
            category: product.category,
            image_url: product.image_url,
            is_active: product.is_active,
            attribute_values: product.attribute_values,
          }}
        />
      </div>

      <VariantSection
        slug={product.slug}
        productName={product.name}
        productPrice={product.price}
        productStock={product.stock}
        attributes={attributes.filter((attribute) =>
          attribute.categories.includes(product.category),
        )}
        variants={variants}
      />
    </main>
  );
}
