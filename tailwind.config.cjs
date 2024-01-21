/** @type {import('tailwindcss').Config} */
export default {
  content: ["./resources/**/*.{html,js,j2}"],
  theme: {
    extend: {},
  },
  plugins: [require("@tailwindcss/typography"), require("daisyui")],
};
