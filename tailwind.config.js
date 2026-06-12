/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        neon: { DEFAULT: "#a855f7", light: "#c084fc", dim: "#7c3aed" },
        dark: { DEFAULT: "#08080f", card: "#12121c", border: "#1e1e2e" }
      },
      boxShadow: { neon: "0 0 20px rgba(168,85,247,0.3)" },
      keyframes: { 'pulse-neon': { '0%,100%': { opacity: '1' }, '50%': { opacity: '0.7' } } },
      animation: { 'pulse-neon': 'pulse-neon 2s ease-in-out infinite' }
    },
  },
  plugins: [],
}
