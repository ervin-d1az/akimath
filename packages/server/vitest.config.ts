import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      reportsDirectory: "coverage",
      // Only testable modules participate in coverage. Environmentally
      // unsuitable modules (process wiring, sockets) live in src/main.ts
      // and behind adapters, and are excluded here on purpose.
      include: ["src/**/*.ts"],
      exclude: ["src/main.ts", "src/adapters/**"],
    },
  },
});
