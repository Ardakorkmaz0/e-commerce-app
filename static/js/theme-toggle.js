(() => {
    const storageKey = "site-theme";
    const root = document.documentElement;

    const readTheme = () => {
        try {
            return localStorage.getItem(storageKey) === "dark" ? "dark" : "light";
        } catch {
            return "light";
        }
    };

    const saveTheme = (theme) => {
        try {
            localStorage.setItem(storageKey, theme);
        } catch {
            // The theme still works when storage is unavailable.
        }
    };

    const applyTheme = (theme, button) => {
        const isDark = theme === "dark";

        root.setAttribute("data-bs-theme", theme);

        if (!button) {
            return;
        }

        const sunIcon = button.querySelector('[data-theme-icon="sun"]');
        const moonIcon = button.querySelector('[data-theme-icon="moon"]');

        sunIcon?.classList.toggle("d-none", isDark);
        moonIcon?.classList.toggle("d-none", !isDark);

        const label = isDark ? "Switch to light theme" : "Switch to dark theme";
        button.setAttribute("aria-label", label);
        button.setAttribute("title", label);
    };

    applyTheme(readTheme());

    document.addEventListener("DOMContentLoaded", () => {
        const button = document.getElementById("themeToggle");

        if (!button) {
            return;
        }

        applyTheme(readTheme(), button);

        button.addEventListener("click", () => {
            const nextTheme = root.getAttribute("data-bs-theme") === "dark"
                ? "light"
                : "dark";

            saveTheme(nextTheme);
            applyTheme(nextTheme, button);
        });
    });
})();
