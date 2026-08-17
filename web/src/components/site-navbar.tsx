import Image from "next/image";
import Link from "next/link";

import { signOut } from "@/app/auth-actions";
import {
  fetchAddresses,
  formatAddressDestination,
  getSelectedAddress,
  type Address,
} from "@/lib/addresses";
import type { AuthenticatedUser } from "@/lib/auth";
import { fetchCartCount } from "@/lib/cart";
import { fetchCategories } from "@/lib/products";

import { AddressSelector } from "./address-selector";
import { CategorySelect } from "./category-select";
import { ThemeToggle } from "./theme-toggle";

type SiteNavbarProps = {
  user: AuthenticatedUser;
};

type AddressTriggerProps = {
  address: Address | null;
  className: string;
};

function AddressTrigger({ address, className }: AddressTriggerProps) {
  const destination = formatAddressDestination(address);

  return (
    <button
      type="button"
      className={`btn site-address-button ${className}`}
      data-bs-toggle="modal"
      data-bs-target="#addressModal"
      aria-label={`Choose delivery address. Current destination: ${destination}`}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="18"
        height="18"
        fill="currentColor"
        viewBox="0 0 16 16"
        aria-hidden="true"
      >
        <path d="M12.166 8.94c-.57 1.166-1.755 2.587-2.722 3.704C8.46 13.78 8 14.5 8 14.5s-.46-.72-1.444-1.856c-.967-1.117-2.152-2.538-2.722-3.704C3.287 7.82 3 6.742 3 5.75a5 5 0 0 1 10 0c0 .992-.287 2.07-.834 3.19M8 8a2.25 2.25 0 1 0 0-4.5A2.25 2.25 0 0 0 8 8" />
      </svg>
      <span className="site-address-copy">
        <small>Deliver to</small>
        <strong>{destination}</strong>
      </span>
    </button>
  );
}

export async function SiteNavbar({ user }: SiteNavbarProps) {
  // Categories come from the database so the dropdown always matches
  // whatever exists in the admin panel.
  const [categories, addresses, cartCount] = await Promise.all([
    fetchCategories(),
    fetchAddresses(),
    fetchCartCount(),
  ]);
  const selectedAddress = getSelectedAddress(addresses);

  return (
    <>
      <nav className="navbar navbar-expand-lg site-navbar sticky-top">
        <div className="container">
          <Link className="navbar-brand d-flex align-items-center gap-2" href="/">
            <Image
              src="/images/logo.png"
              className="site-brand-logo"
              alt="StockCart logo"
              width={44}
              height={44}
              priority
            />
            <span className="d-flex flex-column lh-sm">
              <strong className="site-brand-name">VADER</strong>
              <small className="site-brand-description">Commerce &amp; Inventory</small>
            </span>
          </Link>

          <AddressTrigger
            address={selectedAddress}
            className="site-address-button-desktop d-none d-lg-flex"
          />

          <button
            className="navbar-toggler border-0 shadow-none"
            type="button"
            data-bs-toggle="collapse"
            data-bs-target="#mainNavbar"
            aria-controls="mainNavbar"
            aria-expanded="false"
            aria-label="Toggle navigation"
          >
            <span className="navbar-toggler-icon" />
          </button>

          {/* Outside the collapse on purpose: search is the main way to get
              around, so it must never sit behind the hamburger. On small
              screens it drops onto its own full-width row. */}
          <form
            className="site-search d-flex order-3 order-lg-0 ms-lg-2 me-lg-3 mt-2 mt-lg-0"
            method="get"
            action="/products"
            role="search"
          >
              {/* Department picker, Amazon style. A native select keeps this
                  working without JavaScript and submits with the GET form. */}
              <label className="visually-hidden" htmlFor="searchCategory">
                Category
              </label>
              <CategorySelect categories={categories} />

              <input
                className="form-control"
                type="search"
                name="q"
                placeholder="Search products..."
                aria-label="Search"
              />
              <button className="btn btn-primary" type="submit">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="16"
                  height="16"
                  fill="currentColor"
                  className="bi bi-search"
                  viewBox="0 0 16 16"
                  aria-hidden="true"
                >
                  <path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001q.044.06.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1 1 0 0 0-.115-.1zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0" />
                </svg>
              </button>
          </form>

          <div className="collapse navbar-collapse" id="mainNavbar">
            <div className="site-navbar-actions d-flex align-items-center justify-content-end gap-2 ms-lg-auto py-2 py-lg-0">
              <AddressTrigger
                address={selectedAddress}
                className="site-address-button-mobile d-flex d-lg-none"
              />

              {/* Goes straight to the cart page. The modal it used to open
                  held placeholder text and a link to the same place. */}
              <Link
                className="btn site-cart-button position-relative"
                href="/cart"
                aria-label={`Shopping cart, ${cartCount} item${cartCount === 1 ? "" : "s"}`}
              >
                Cart
                {cartCount > 0 ? (
                  <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger">
                    {cartCount}
                  </span>
                ) : null}
              </Link>

              <div className="dropdown">
                <button
                  className="btn site-account-button dropdown-toggle"
                  type="button"
                  data-bs-toggle="dropdown"
                  aria-expanded="false"
                >
                  {user.username}
                </button>

                <ul className="dropdown-menu dropdown-menu-end border-0 shadow">
                  <li>
                    <span className="dropdown-header">
                      Signed in as
                      <br />
                      <strong>{user.username}</strong>
                    </span>
                  </li>
                  <li><hr className="dropdown-divider" /></li>
                  <li>
                    <Link className="dropdown-item" href="/profile">Profile</Link>
                  </li>
                  <li>
                    <Link className="dropdown-item" href="/myorders">My Orders</Link>
                  </li>
                  <li>
                    <Link className="dropdown-item" href="/profile/addresses">
                      Addresses
                    </Link>
                  </li>
                  <li>
                    <Link className="dropdown-item" href="/profile/payment-methods">
                      Payment Methods
                    </Link>
                  </li>
                  {user.is_seller ? (
                    <li>
                      <Link className="dropdown-item" href="/seller">My Products</Link>
                    </li>
                  ) : null}
                  {user.is_staff ? (
                    <li>
                      <a className="dropdown-item" href="http://127.0.0.1:8000/admin/">
                        Admin Panel
                      </a>
                    </li>
                  ) : null}
                  <li><hr className="dropdown-divider" /></li>
                  <li>
                    <form action={signOut}>
                      <button className="dropdown-item text-danger" type="submit">Sign out</button>
                    </form>
                  </li>
                </ul>
              </div>

              <ThemeToggle />
            </div>
          </div>
        </div>
      </nav>

      <div
        className="modal fade site-address-modal"
        id="addressModal"
        tabIndex={-1}
        aria-labelledby="addressModalLabel"
        aria-hidden="true"
      >
        <div className="modal-dialog modal-dialog-centered modal-dialog-scrollable">
          <div className="modal-content address-modal-content">
            <div className="modal-header">
              <div>
                <span className="address-modal-eyebrow">Delivery destination</span>
                <h1 className="modal-title fs-5" id="addressModalLabel">
                  Choose your address
                </h1>
              </div>
              <button
                type="button"
                className="btn-close"
                data-bs-dismiss="modal"
                aria-label="Close"
              />
            </div>
            <div className="modal-body">
              <AddressSelector addresses={addresses} />
            </div>
          </div>
        </div>
      </div>

    </>
  );
}
