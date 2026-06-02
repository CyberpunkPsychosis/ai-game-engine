import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// base: './' 让构建产物用相对路径，可部署到 /tools/sprite-rigger/ 子目录
export default defineConfig({
  base: "./",
  plugins: [react(), tailwindcss()],
});
