import { redirect } from "next/navigation";

import { ScrollToTop } from "@/components/scroll-to-top";
import { SiteNavbar } from "@/components/site-navbar";
import { getCurrentUser } from "@/lib/auth";

type StoreLayoutProps = Readonly<{
  children: React.ReactNode;
}>;

export default async function StoreLayout({ children }: StoreLayoutProps) {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/signin");
  }

  return (
    <>
      <SiteNavbar user={user} />
      {children}
      <ScrollToTop />
    </>
  );
}
