import { SiteNavbar } from "@/components/site-navbar";

type StoreLayoutProps = Readonly<{
  children: React.ReactNode;
}>;

export default function StoreLayout({ children }: StoreLayoutProps) {
  return (
    <>
      <SiteNavbar />
      {children}
    </>
  );
}
