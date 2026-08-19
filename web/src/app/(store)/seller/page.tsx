import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { VerifiedSellerBadge } from "@/components/verified-seller-badge";
import { getCurrentUser } from "@/lib/auth";
import { formatPrice } from "@/lib/products";
import { fetchSellerProducts } from "@/lib/seller";

import { deleteProduct } from "./actions";

export const metadata: Metadata = {
  title: "My Products",
};

export default async function SellerPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }
  // The API enforces this too; this only avoids rendering a dead page.
  if (!user.is_seller) {
    redirect("/");
  }

  const products = await fetchSellerProducts();

  return (
    <main className="container py-4">
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-4">
        <div>
          <div className="d-flex align-items-center gap-2 mb-1">
            <h1 className="section-title mb-0">
              {user.store_name || user.username}
            </h1>
            {user.is_verified_seller ? <VerifiedSellerBadge /> : null}
          </div>
          <p className="mb-0" style={{ color: "var(--site-muted-text)" }}>
            Seller dashboard &middot; {products.length} listing
            {products.length === 1 ? "" : "s"}
          </p>
        </div>
        <div className="d-flex gap-2">
          <Link className="btn btn-outline-secondary" href="/seller/orders">
            Orders
          </Link>
          <Link className="btn btn-outline-secondary" href="/profile/edit">
            Edit store profile
          </Link>
          <Link className="btn signin-submit-button" href="/seller/new">
            Add product
          </Link>
        </div>
      </div>

      {products.length ? (
        <div className="table-responsive seller-table">
          <table className="table align-middle mb-0">
            <thead>
              <tr>
                <th scope="col">Product</th>
                <th scope="col">Category</th>
                <th scope="col">Price</th>
                <th scope="col">Stock</th>
                <th scope="col">Status</th>
                <th scope="col" className="text-end">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {products.map((product) => (
                <tr key={product.id}>
                  <td>
                    <div className="d-flex align-items-center gap-2">
                      {product.image_display ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={product.image_display}
                          alt=""
                          className="seller-thumb"
                        />
                      ) : (
                        <span className="seller-thumb seller-thumb-empty" />
                      )}
                      <span className="fw-semibold">{product.name}</span>
                    </div>
                  </td>
                  <td>{product.category_name}</td>
                  <td>{formatPrice(product.price)}</td>
                  <td>{product.stock}</td>
                  <td>
                    {product.is_active ? (
                      <span className="stock-badge">Visible</span>
                    ) : (
                      <span className="stock-badge out">Hidden</span>
                    )}
                  </td>
                  <td>
                    <div className="d-flex justify-content-end gap-2">
                      <Link
                        className="btn btn-sm btn-outline-secondary"
                        href={`/seller/${product.slug}/edit`}
                      >
                        Edit
                      </Link>
                      <form action={deleteProduct}>
                        <input type="hidden" name="slug" value={product.slug} />
                        <button className="btn btn-sm btn-outline-danger" type="submit">
                          Delete
                        </button>
                      </form>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="empty-state">
          <p className="mb-3">You have no products yet.</p>
          <Link className="btn signin-submit-button" href="/seller/new">
            Add your first product
          </Link>
        </div>
      )}
    </main>
  );
}
