"use client";

import { useEffect, useState } from "react";

/**
 * Back-to-top button. Appears once the page has scrolled far enough that
 * returning to the header by hand would be tedious.
 */
export function ScrollToTop() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const onScroll = () => setVisible(window.scrollY > 600);

    onScroll(); // The page may already be scrolled on a back navigation.
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <button
      type="button"
      className={`scroll-to-top${visible ? " visible" : ""}`}
      aria-label="Back to top"
      title="Back to top"
      // Hidden from keyboard and screen readers while off screen.
      aria-hidden={!visible}
      tabIndex={visible ? 0 : -1}
      onClick={() => {
        // `smooth` is ignored when the visitor asks for reduced motion.
        window.scrollTo({ top: 0, behavior: "smooth" });
      }}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="20"
        height="20"
        fill="currentColor"
        viewBox="0 0 16 16"
        aria-hidden="true"
      >
        <path
          fillRule="evenodd"
          d="M8 12a.5.5 0 0 0 .5-.5V5.707l2.146 2.147a.5.5 0 0 0 .708-.708l-3-3a.5.5 0 0 0-.708 0l-3 3a.5.5 0 1 0 .708.708L7.5 5.707V11.5a.5.5 0 0 0 .5.5"
        />
      </svg>
    </button>
  );
}
