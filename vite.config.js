import { defineConfig, searchForWorkspaceRoot } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";
import path from "path";
import { createHtmlPlugin } from "vite-plugin-html";

export default defineConfig({
  root: "resources/",
  assetsInclude: ["**/*.xml", "**/*.j2"],
  server: {
    fs: {
      allow: [
        searchForWorkspaceRoot(process.cwd()),
        path.join(__dirname, "resources"),
        path.join(__dirname, "node_modules"),
      ],
    },
    watch: {
      ignored: [
        "**/.venv/**",
        "./deploy",
        "/docs",
        "src",
        "node_modules",
        "scripts",
        "dist/",
        "**/__pycache__/**",
      ],
    },
  },
  plugins: [
    viteSingleFile({ removeViteModuleLoader: true }),
    createHtmlPlugin({
      pages: [
        {
          template: "templates/quick-check.html",
          filename: "quick-check.html",
        },
      ],
    }),
  ],
  build: {
    outDir: path.resolve(__dirname, "src/dma/templates"),
  },
  alias: {
    "@": path.resolve(__dirname, "resources"),
  },
});
