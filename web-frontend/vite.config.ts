import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    allowedHosts: [
      '.sourishkanna.me'              // Wildcard for any subdomain on your domain
    ],
    host: '0.0.0.0',
    port: 7004
  }
})