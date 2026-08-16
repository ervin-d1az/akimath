import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    // Pinned at vitest's current default rather than raised: the slowest test
    // in this package is 88ms, so 5s is already ~57x headroom, and writing it
    // down keeps a future default change from quietly loosening the gate.
    //
    // What it does and does not do, measured rather than assumed: a test that
    // awaits a promise nobody resolves fails here in ~2s, but a synchronous
    // loop with no exit is *not* interrupted — vitest's timer cannot preempt a
    // busy worker, and a probe was still spinning after 20s. The bounds that
    // survive that case are outside vitest: `timeout-minutes` on every job in
    // .github/workflows/ci.yml, and the per-command deadline in
    // .claude/hooks/verify-gate.sh.
    testTimeout: 5_000,
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      reportsDirectory: "coverage",
      // Mirrors packages/server: only the pure modules participate. The one
      // module that touches the filesystem lives behind src/adapters/ and is
      // excluded here on purpose (D9).
      include: ["src/**/*.ts"],
      exclude: ["src/adapters/**"],
    },
  },
});
