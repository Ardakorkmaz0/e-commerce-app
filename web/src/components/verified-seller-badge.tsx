type VerifiedSellerBadgeProps = {
  compact?: boolean;
};

export function VerifiedSellerBadge({ compact = false }: VerifiedSellerBadgeProps) {
  return (
    <span
      className={`verified-seller-badge${compact ? " compact" : ""}`}
      title="Verified seller"
      aria-label="Verified seller"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="14"
        height="14"
        fill="currentColor"
        viewBox="0 0 16 16"
        aria-hidden="true"
      >
        <path d="M16 8a8 8 0 1 1-16 0 8 8 0 0 1 16 0m-3.97-3.03a.75.75 0 0 0-1.08.02L6.48 10.69 4.06 8.27a.75.75 0 0 0-1.06 1.06l3 3a.75.75 0 0 0 1.08-.02l4.97-6.27a.75.75 0 0 0-.02-1.07" />
      </svg>
      {compact ? null : <span>Verified</span>}
    </span>
  );
}
