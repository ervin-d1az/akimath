import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    // Mirrors packages/contract: vitest's current default, pinned so it cannot
    // drift, and honest about its reach. It catches a promise nobody resolves;
    // it does not interrupt a synchronous loop with no exit. The process-level
    // bounds in .github/workflows/ci.yml and .claude/hooks/verify-gate.sh are
    // what catch that one.
    testTimeout: 5_000,
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
