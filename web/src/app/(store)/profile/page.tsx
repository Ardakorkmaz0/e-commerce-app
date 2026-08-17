import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { signOut } from "@/app/auth-actions";
import { VerifiedSellerBadge } from "@/components/verified-seller-badge";
import { getCurrentUser } from "@/lib/auth";

export const metadata: Metadata = {
  title: "Profile",
};

// Mirrors ProfileTab in the Flutter app.
export default async function ProfilePage() {
  // The store layout already guards this, but a page can be requested
  // directly, so the user is re-read here rather than assumed.
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  const displayName =
    `${user.first_name} ${user.last_name}`.trim() || user.username;

  return (
    <main className="container py-4" style={{ maxWidth: "640px" }}>
      <div className="profile-card p-4 mb-4">
        <div className="d-flex align-items-center gap-3">
          <div className="profile-avatar">
            {user.username.slice(0, 1).toUpperCase()}
          </div>
          <div>
            <div className="fw-bold fs-5" style={{ color: "var(--site-text)" }}>
              {displayName}
            </div>
            <div style={{ color: "var(--site-muted-text)" }}>{user.email}</div>
            {user.is_seller ? (
              <div className="profile-store-name mt-2">
                <span>{user.store_name || user.username}</span>
                {user.is_verified_seller ? <VerifiedSellerBadge /> : null}
              </div>
            ) : null}
          </div>
        </div>
      </div>

      <div className="list-group profile-menu mb-4">
        <Link className="list-group-item list-group-item-action" href="/myorders">
          My Orders
        </Link>
        <Link
          className="list-group-item list-group-item-action"
          href="/profile/addresses"
        >
          Addresses
        </Link>
        <Link
          className="list-group-item list-group-item-action"
          href="/profile/payment-methods"
        >
          Payment Methods
        </Link>
        <Link className="list-group-item list-group-item-action" href="/profile/edit">
          Edit Profile
        </Link>
        {user.is_staff ? (
          <a
            className="list-group-item list-group-item-action"
            href="http://127.0.0.1:8000/admin/"
          >
            Admin Panel
          </a>
        ) : null}
      </div>

      <form action={signOut}>
        <button className="btn btn-outline-danger w-100" type="submit">
          Sign out
        </button>
      </form>
    </main>
  );
}
