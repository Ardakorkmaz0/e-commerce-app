import Image from "next/image";
import Link from "next/link";

import { signOut } from "@/app/auth-actions";
import type { AuthenticatedUser } from "@/lib/auth";

import { ThemeToggle } from "./theme-toggle";

type SiteNavbarProps = {
  user: AuthenticatedUser;
};

export function SiteNavbar({ user }: SiteNavbarProps) {
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

          <div className="collapse navbar-collapse" id="mainNavbar">
            <ul className="navbar-nav ms-lg-4 me-auto mb-3 mb-lg-0">
              <li className="nav-item">
                <Link className="nav-link site-nav-link" href="/">
                  Home
                </Link>
              </li>
              <li className="nav-item">
                <Link className="nav-link site-nav-link" href="/categories">
                  Categories
                </Link>
              </li>
              <li className="nav-item">
                <Link className="nav-link site-nav-link" href="/products">
                  Products
                </Link>
              </li>
            </ul>

            <form className="site-search d-flex me-lg-3 mb-3 mb-lg-0" method="get" action="/" role="search">
              <input
                className="form-control"
                type="search"
                name="q"
                placeholder="Search..."
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

            <div className="d-flex align-items-center justify-content-end gap-2 ms-lg-auto">
              <button
                type="button"
                className="btn site-cart-button position-relative"
                aria-label="Shopping cart"
                data-bs-toggle="modal"
                data-bs-target="#cartModal"
              >
                Cart
                <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger">
                  0
                </span>
              </button>

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
        className="modal fade"
        id="cartModal"
        tabIndex={-1}
        aria-labelledby="cartModalLabel"
        aria-hidden="true"
      >
        <div className="modal-dialog modal-dialog-centered modal-dialog-scrollable">
          <div className="modal-content">
            <div className="modal-header">
              <h1 className="modal-title fs-5" id="cartModalLabel">Cart</h1>
              <button type="button" className="btn-close" data-bs-dismiss="modal" aria-label="Close" />
            </div>
            <div className="modal-body">Orders</div>
            <div className="modal-footer">
              <form action="/cart" method="get">
                <button type="submit" className="btn btn-primary">
                  Go to Cart
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
