// Mirrors _ProductCardPlaceholder in the Flutter app (home_tab.dart).
// Shown until the backend exposes real products.
export function ProductCardPlaceholder() {
  return (
    <div className="product-card d-flex flex-column">
      <div className="product-card-media">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="48"
          height="48"
          fill="currentColor"
          viewBox="0 0 16 16"
          aria-hidden="true"
        >
          <path d="M6.002 5.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0" />
          <path d="M2.002 1a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2zm12 1a1 1 0 0 1 1 1v6.5l-3.777-1.947a.5.5 0 0 0-.577.093l-3.71 3.71-2.66-1.772a.5.5 0 0 0-.63.062L1.002 12V3a1 1 0 0 1 1-1z" />
        </svg>
      </div>

      <div className="p-3 d-flex flex-column gap-2">
        <div className="skeleton-line" />
        <div className="skeleton-line accent" />
      </div>
    </div>
  );
}

// Renders a responsive grid of placeholder cards.
export function ProductGridPlaceholder({ count = 6 }: { count?: number }) {
  return (
    <div className="row row-cols-2 row-cols-md-3 row-cols-lg-4 g-3">
      {Array.from({ length: count }, (_, index) => (
        <div className="col" key={index}>
          <ProductCardPlaceholder />
        </div>
      ))}
    </div>
  );
}
