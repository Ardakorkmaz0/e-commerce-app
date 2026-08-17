/** Brand marks drawn inline so no third-party asset is loaded. */
export function CardBrandLogo({ brand }: { brand: "visa" | "mastercard" }) {
  if (brand === "visa") {
    return (
      <span className="card-brand card-brand-visa" aria-label="Visa">
        VISA
      </span>
    );
  }

  return (
    <span className="card-brand" aria-label="Mastercard">
      <svg width="34" height="21" viewBox="0 0 34 21" aria-hidden="true">
        <circle cx="13" cy="10.5" r="8.5" fill="#EB001B" />
        <circle cx="21" cy="10.5" r="8.5" fill="#F79E1B" />
        {/* The overlap is the mark's defining feature. */}
        <path
          d="M17 3.9a8.5 8.5 0 0 0 0 13.2 8.5 8.5 0 0 0 0-13.2Z"
          fill="#FF5F00"
        />
      </svg>
    </span>
  );
}
