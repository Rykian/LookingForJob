/// <reference types="vitest/config" />
import path, { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

const dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [RubyPlugin(), react(), tailwindcss()],
  resolve: {
    alias: {
      '@': resolve(dirname, 'app/frontend'),
    },
  },
})
