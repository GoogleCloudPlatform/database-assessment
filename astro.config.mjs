import { defineConfig } from "astro/config"
import tailwind from "@astrojs/tailwind"
import mdx from "@astrojs/mdx"
import singleFile from "astro-single-file"
const ASSET_URL = process.env.ASSET_URL || "/"
const VITE_PORT = process.env.VITE_PORT || "5173"
const VITE_HOST = process.env.VITE_HOST || "localhost"

// https://astro.build/config
export default defineConfig({
  srcDir: "resources/",
  outDir: "src/dma/static",
  base: `${ASSET_URL}`,
  server: {
    host: `${VITE_HOST}`,
    port: +`${VITE_PORT}`,
    cors: true,
  },
  build: {
    format: "file",
    client: "src/dma/static",
  },
  integrations: [
    tailwind({
      nesting: true,
    }),
    mdx(),
  ],
  resolve: {
    alias: {
      "@": "./resources",
    },
  },
})
