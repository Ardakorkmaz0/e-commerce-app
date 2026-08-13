import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth";

import { EditProfileForm } from "./edit-profile-form";

export const metadata: Metadata = {
  title: "Edit Profile",
};

// Mirrors EditProfileScreen in the Flutter app.
export default async function EditProfilePage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  return (
    <main className="container py-4" style={{ maxWidth: "560px" }}>
      <div className="profile-card p-4">
        <div className="d-flex flex-column align-items-center mb-4">
          <div className="profile-avatar mb-2">
            {user.username.slice(0, 1).toUpperCase()}
          </div>
          <span style={{ color: "var(--site-muted-text)" }}>@{user.username}</span>
        </div>

        {/* The username is not editable — the backend only accepts
            email, first_name and last_name on PATCH /auth/me/. */}
        <EditProfileForm
          defaultValues={{
            email: user.email,
            firstName: user.first_name,
            lastName: user.last_name,
          }}
        />
      </div>
    </main>
  );
}
