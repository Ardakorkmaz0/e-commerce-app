/**
 * Where to send a shopper back to after a detour.
 *
 * Checkout sends people off to add an address or a card and needs them
 * back afterwards, so the destination travels in the query string. That
 * makes it attacker-controlled: a link like
 * `?next=https://evil.example` would otherwise turn our own redirect into
 * somebody else's landing page. Only a plain internal path is allowed —
 * one leading slash, and nothing that could be read as a host.
 */
export function safeNext(value: string | undefined | null): string | null {
  if (!value) return null;
  if (!value.startsWith("/")) return null;

  // "//evil.example" and "/\evil.example" are both protocol-relative.
  if (value.startsWith("//") || value.startsWith("/\\")) return null;

  // A scheme cannot appear in a path, so a colon before the first slash
  // means somebody is trying "javascript:" or similar.
  if (/^\/[^/]*:/.test(value)) return null;

  return value;
}
