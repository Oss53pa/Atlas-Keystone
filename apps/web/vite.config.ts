import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath, URL } from 'node:url';

const root = (p: string) => fileURLToPath(new URL(p, import.meta.url));

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@keystone/ui': root('../../packages/ui/src'),
      '@keystone/domain': root('../../packages/domain/src'),
    },
  },
  server: { port: 5180, strictPort: true, host: true },
});
