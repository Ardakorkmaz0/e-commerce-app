import Image from "next/image";
import Link from "next/link";

export function SiteNavbar() {
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
                data-bs-target="#exampleModal"
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
                  Username
                </button>

                <ul className="dropdown-menu dropdown-menu-end border-0 shadow">
                  <li>
                    <span className="dropdown-header">
                      Signed in as
                      <br />
                      <strong>Username</strong>
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
                    <a className="dropdown-item" href="http://127.0.0.1:8000/admin/">Admin Panel</a>
                  </li>
                  <li><hr className="dropdown-divider" /></li>
                  <li>
                    <form method="post" action="/signout">
                      <button className="dropdown-item text-danger" type="submit">Sign out</button>
                    </form>
                  </li>
                </ul>
              </div>

              <button
                className="btn site-theme-button border rounded-circle d-inline-flex align-items-center justify-content-center p-2"
                type="button"
                id="themeToggle"
                aria-label="Toggle color theme"
                title="Toggle theme"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="18"
                  height="18"
                  fill="currentColor"
                  className="bi bi-sun"
                  viewBox="0 0 16 16"
                  aria-hidden="true"
                  data-theme-icon="sun"
                >
                  <path d="M8 11a3 3 0 1 1 0-6 3 3 0 0 1 0 6m0 1a4 4 0 1 0 0-8 4 4 0 0 0 0 8M8 0a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 0m0 13a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 13m8-5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2a.5.5 0 0 1 .5.5M3 8a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2A.5.5 0 0 1 3 8m10.657-5.657a.5.5 0 0 1 0 .707l-1.414 1.415a.5.5 0 1 1-.707-.708l1.414-1.414a.5.5 0 0 1 .707 0m-9.193 9.193a.5.5 0 0 1 0 .707L3.05 13.657a.5.5 0 0 1-.707-.707l1.414-1.414a.5.5 0 0 1 .707 0m9.193 2.121a.5.5 0 0 1-.707 0l-1.414-1.414a.5.5 0 0 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .707M4.464 4.465a.5.5 0 0 1-.707 0L2.343 3.05a.5.5 0 1 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .708" />
                </svg>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="18"
                  height="18"
                  fill="currentColor"
                  className="bi bi-moon-fill d-none"
                  viewBox="0 0 16 16"
                  aria-hidden="true"
                  data-theme-icon="moon"
                >
                  <path d="M6 .278a.768.768 0 0 1 .08.858 7.208 7.208 0 0 0-.878 3.46c0 4.021 3.278 7.277 7.318 7.277.527 0 1.04-.055 1.533-.16a.787.787 0 0 1 .81.316.733.733 0 0 1-.031.893A8.349 8.349 0 0 1 8.344 16C3.734 16 0 12.286 0 7.71 0 4.266 2.114 1.312 5.124.06A.752.752 0 0 1 6 .278" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </nav>

      <div
        className="modal fade"
        id="exampleModal"
        tabIndex={-1}
        aria-labelledby="exampleModalLabel"
        aria-hidden="true"
      >
        <div className="modal-dialog modal-dialog-centered modal-dialog-scrollable">
          <div className="modal-content">
            <div className="modal-header">
              <h1 className="modal-title fs-5" id="exampleModalLabel">Cart</h1>
              <button type="button" className="btn-close" data-bs-dismiss="modal" aria-label="Close" />
            </div>
            <div className="modal-body">Orders</div>
            <div className="modal-footer">
              <Link href="/cart" className="btn btn-primary">Go to Cart</Link>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
