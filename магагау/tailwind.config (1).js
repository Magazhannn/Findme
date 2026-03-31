/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: "#F9F8F6",   // Warm sand beige / Off-white
        surface: "#FFFFFF",
        primary: {
          DEFAULT: "#8FA189",    // Sage green
          hover:   "#7A8C74",
          light:   "#F0F4EF",
        },
        secondary: "#D4A398",    // Dusty rose
        accent:    "#C2856F",    // Terracotta — use sparingly
        text: {
          main:  "#2D3134",      // Anthracite dark gray
          muted: "#8A8F93",
        },
      },
      fontFamily: {
        sans: ["Inter", "Open Sans", "sans-serif"],
      },
      borderRadius: {
        xl:  "1rem",
        "2xl": "1.5rem",
        "3xl": "2rem",
      },
      boxShadow: {
        soft: "0 10px 40px -10px rgba(0,0,0,0.05)",
        card: "0 4px 24px -4px rgba(0,0,0,0.07)",
      },
      transitionTimingFunction: {
        organic: "cubic-bezier(0.4, 0, 0.2, 1)",
      },
      transitionDuration: {
        slow: "800ms",
      },
    },
  },
  plugins: [],
};
