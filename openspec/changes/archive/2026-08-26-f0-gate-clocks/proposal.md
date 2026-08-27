# Put a clock on every gate

**Phase:** F0. Not in `ARCHITECTURE.md` §9's original F0 list — it was found during the
`f0-pack-contract` review and is recorded here rather than folded silently into that change.

## Why

Nothing that runs a check in this repository has a time limit. Verified before writing:

```
grep -n "timeout" .claude/hooks/verify-gate.sh .github/workflows/ci.yml packages/*/vitest.config.ts
→ no matches
```

That is not a theoretical gap. The uniqueness solver in `packages/contract` shipped without a node
budget, and a `size: 6` Kakuro the schema explicitly permits does not return — measured at **over
five minutes before being killed**, on the order of sixteen hours if left alone. With no clock
anywhere, that one bug surfaces three times, each time as a silence rather than an error:

1. `npm run emit` freezes — and regenerating artifacts is the first thing a content author does
   after adding a fixture, so they meet it before any test.
2. `git commit` then blocks forever. `run_check` prints only on a non-zero exit, so a hung check
   produces **no output at all**: the commit simply never returns.
3. The `contract` CI job inherits GitHub's six-hour default while `gate` never reports, so a pull
   request waits on a check that is still running.

The solver's budget is fixed in `f0-pack-contract`. This change fixes the reason its absence was
invisible. A gate that hangs is worse than a gate that does not exist: the absent one is honest.

## What changes

- **`.claude/hooks/verify-gate.sh`** — every check runs under a deadline. On expiry the hook exits
  2 and names *which* command was killed, so the developer is not left guessing which of four
  checks hung. `AKIMATH_GATE_TIMEOUT` overrides it and is validated, because a gate that cannot
  read its own deadline must not run unbounded.
- **`.github/workflows/ci.yml`** — `timeout-minutes` on every job, sized per job rather than one
  blanket number.
- **`packages/server/vitest.config.ts`** and **`packages/contract/vitest.config.ts`** —
  `testTimeout`, so a hung test fails as a test instead of hanging the suite that contains it.

## Non-goals

- **Not making anything faster.** The deadline turns a hang into a named failure; it does not
  address why something was slow.
- **Not a Dart-side deadline.** `flutter test` has its own per-test timeout, and the hook's
  deadline already wraps the whole command.
- **No retry, no backoff.** A check that times out is a failure to look at, not to paper over.

## What it builds on

- `.claude/hooks/verify-gate.sh` already exists and already exits 2 on failure; this adds the
  clock, and does not change which checks run or in what order.
- `.github/workflows/ci.yml` already runs six jobs behind a single `gate`.
- Portability matters here: GNU `timeout` is **not** present on macOS, where the hook actually
  runs, so the deadline cannot be implemented with it.
