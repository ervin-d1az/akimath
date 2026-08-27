## Why

**Phase F1** (`ARCHITECTURE.md` §9). `packages/core` is not a utility library — it is the
**rederivation machine**, and one invariant governs it: `attempts` is append-only, so the server
must reconstruct the exact problem *years later, on a different Node*, from what `issued_items`
stored. Every decision below is what happens when you ask how that could break.

Nothing on disk can do it today. `packages/server` holds the schema that records
`(template_id, template_version, seed, ladder_step)` and nothing that turns those back into an item.
`f1-5-pack-builder` is blocked on this, and `f2-stimulus-families` is blocked on that — which is to
say the app's content pipeline starts here.

It is also where the rating lives. `user_skills` is already frozen as
`(player_id, skill_id, rating real, deviation real, updated_at)` — Glicko-**1** shaped, with no
volatility column, which is what Glicko-2 would need.

## What Changes

- **`packages/core`, the repository's third TypeScript package and its first with a zero-runtime-
  dependency gate.** No `dependencies` key at all, enforced by a test that reads `package.json`
  rather than by a resolver — `ARCHITECTURE.md` §3 names the one-line diff that kills a
  resolution-based invariant.
- **A determinism gate over the source**: `Math.random`, `Date`, `performance`,
  `crypto.randomUUID`, `Intl` and `toLocaleString` are refused. An import ban cannot catch
  `Math.random()`, so it is an AST walk, not a lint rule.
- **BigInt rationals** — a method-free frozen interface with no `toString`, deliberately.
- **A vendored splitmix64**, addressed by index rather than by advancing state, with its golden
  vector **emitted from the code** and anchored to Vigna's published reference.
- **Glicko-1 with the session as the rating period**, and `decay(prior, elapsedDays)` in days.
  Outputs are narrowed with `Math.fround`, which is what makes a byte-exact rating fixture possible
  at all — see design D11.
- **The rederivation mechanism plus one worked reference template**, versioned so an old attempt
  rederives with the old behaviour after the template is revised.
- **One export added to `packages/contract`**: `renderCanonicalAnswer`. Core produces rationals and
  never produces an answer string, because the rule for what `5/4` means is already frozen, already
  golden-tested, and already checked from Dart.
- CI grows a `core` job and the path filters that make the cross-package edges bite in both
  directions.

**BREAKING**: none. Nothing consumes `packages/core` yet.

## Capabilities

### New Capabilities

- `domain-core`: what the rederivation machine guarantees — determinism, the PRNG, rationals,
  template versioning, and the rating.

### Modified Capabilities

None. `packages/contract` has no spec on disk; its one new export is covered by `domain-core`'s
`req-contract-render`, which is where the obligation it creates actually lives.

## Impact

**Created** — the `packages/core` tree: `src/rational.ts`, `src/template.ts`, `src/registry.ts`,
`src/prng/splitmix64.ts`, `src/rating/glicko.ts`, `src/rating/decay.ts`, one versioned reference
template, one adapter that writes the three golden artifacts, and the committed artifacts
themselves.

**Modified** — `packages/contract/src/canon.ts` gains `renderCanonicalAnswer` and its
`CANON_INPUTS` gains five rendered shapes, which regenerates
`contract/fixtures/canon.golden.json`. `.github/workflows/ci.yml` gains a `core` job and two filter
corrections. `ARCHITECTURE.md`, `CLAUDE.md` and `docs/IMPLEMENTATION-PLAN.md` are corrected where
they describe this package wrongly.

**A frozen artifact moves, and that is the riskiest edit in the change.**
`contract/fixtures/canon.golden.json` is the one file binding the TypeScript and Dart
canonicalisers — risk R2. Extending it buys Dart coverage of every rendered shape with zero Dart
edits, because the Dart parity test iterates whatever the fixture contains. It also means the Dart
suite **must** re-run when it moves, and today's path filters do not make it. That is fixed here.

## Non-goals

- **The template library.** One reference template proves the mechanism; the others are
  `f1-5-pack-builder`, where the content decisions live and where risk R3 already says the ceiling
  is.
- **Where an opponent rating comes from.** Glicko-1 needs an opponent `(rating, deviation)` per
  outcome and **nothing in the frozen schema supplies one** — `template_stats` has no rating column
  and `ladder_step` is not a rating. Core takes it as a parameter and decides nothing about its
  provenance, so it is correct under every candidate; but nothing can rate a real player until that
  is settled. It is the first open question in `design.md` and it belongs to `f3-attempt-sync`.
- **Series uniqueness (`k ≥ dof+2`).** A property of a rule *library*, and there is no library here.
- **Any endpoint, any migration, any Dart.** `app/` is untouched except that its existing
  cross-stack parity test starts iterating five more vectors, which is the point.
- **`packages/core` consuming `packages/contract` at runtime.** It takes it as a **dev**
  dependency, used only to prove core's output is acceptable to the frozen format. Verification,
  not reuse — see design D1.
