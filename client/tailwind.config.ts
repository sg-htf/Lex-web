import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary:    "hsl(var(--color-primary))",
        secondary:  "hsl(var(--color-secondary))",
        background: "hsl(var(--color-background))",
        foreground: "hsl(var(--color-foreground))",
        muted:      "hsl(var(--color-muted))",
        border:     "hsl(var(--color-border))",
      },
    },
  },
  plugins: [],
};
export default config;
