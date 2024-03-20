import path from "path"
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from "vite-plugin-singlefile"

import tailwind from "tailwindcss"
import autoprefixer from "autoprefixer"

// https://vitejs.dev/config/
export default defineConfig({
    css: {
        postcss: {
            plugins: [tailwind(), autoprefixer()],
        },
      },
    plugins: [vue(), viteSingleFile()],
    server: {
        port: 8080,
    },
    resolve: {
        alias: {
          "@": path.resolve("./src"),
        },
      },    
})
