/** @type {import('tailwindcss').Config} */
export default {
  darkMode: ["class"],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Paleta Casa Militar (SPEC §7) via CSS vars.
        brand: {
          DEFAULT: "var(--brand-primary)",
          hover: "var(--brand-primary-hover)",
          container: "var(--brand-primary-container)",
          fg: "var(--brand-on-primary)",
        },
        gold: {
          DEFAULT: "var(--brand-secondary)",
          container: "var(--brand-secondary-container)",
          fg: "var(--brand-on-secondary)",
        },
        lime: {
          DEFAULT: "var(--accent-lime)",
          container: "var(--accent-lime-container)",
          fg: "var(--accent-on-lime)",
        },
        info: "var(--accent-info)",
        base: "var(--bg-base)",
        surface: {
          DEFAULT: "var(--bg-surface)",
          alt: "var(--bg-surface-alt)",
        },
        line: {
          DEFAULT: "var(--line-outline)",
          input: "var(--line-input)",
        },
        content: {
          DEFAULT: "var(--text-primary)",
          soft: "var(--text-secondary)",
          faint: "var(--text-disabled)",
        },
        success: "var(--status-success)",
        warning: "var(--status-warning)",
        danger: "var(--status-error)",
      },
      borderRadius: {
        sm: "8px",
        md: "12px",
        lg: "20px",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
      // Escala de elevação (design-system.md §6) — sombra suave, nunca pesada.
      boxShadow: {
        1: "0 1px 2px rgba(16,24,18,.05), 0 4px 16px rgba(16,24,18,.04)",
        2: "0 4px 12px rgba(16,24,18,.08), 0 2px 4px rgba(16,24,18,.06)",
        3: "0 12px 32px rgba(16,24,18,.16)",
      },
      // Movimento (design-system.md §8) — curto e funcional, sem bounce.
      transitionDuration: {
        fast: "120ms",
        base: "200ms",
        slow: "320ms",
      },
      transitionTimingFunction: {
        standard: "cubic-bezier(.2,0,0,1)",
      },
    },
  },
  plugins: [],
};
