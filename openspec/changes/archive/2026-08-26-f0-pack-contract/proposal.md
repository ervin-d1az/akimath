## Why

The offline pack format is the one artifact both stacks read, and `docs/IMPLEMENTATION-PLAN.md`
§5.4 calls this change **the one thing that must not slip**: it sits upstream of the Dart lane
(`f1b-content-reader`) and the TypeScript lane (`f1-core-rederivation` → `f1-5-pack-builder`), so if
it moves, `ARCHITECTURE.md` §9's two parallel tracks collapse into a serial chain and the first
playable slides by whatever the TypeScript lane costs.

Phase **F0** of `ARCHITECTURE.md` §9. It freezes the format as a versioned, committed artifact with
golden fixtures so the Dart side can read a hand-written fixture pack on day one, before any pack
builder, any database and any endpoint exists. `ARCHITECTURE.md` §1 lists the offline pack format
and `canon.golden.json` + `CHAR_MAP` as two of the six cross-stack contracts; §6 says the boundary
between the stacks is *"a directory of pinned, versioned artifacts, not a handoff."* This change
creates that directory.

**Depends on: the pre-F1 decisions in §5.1 — satisfied, not blocking.** Gate B closed on
2026-08-15 (§7.0 A), and the four decisions that reach the pack — Q2 (diagnosis payload), Q4
(rating delta per series), Q5 (a player has no name) and §7.0 B (node state) — are all answered.
Nothing here waits on a person.

## What Changes

- **New package `packages/contract`** (`@akimath/contract`): the Zod schemas for the offline pack,
  the answer canonicalizer, and the validators that reject a malformed pack. All pure (PURE-1);
  the script that writes bytes is the one adapter beside them (PURE-2).
- **The prompt is `{ kind, payload }`, not a token stream.** `kind` is the closed six-member enum
  of the plan's §3.4 sealed `Stimulus`; `payload` is an opaque per-kind object with one Zod schema
  each. This **corrects `ARCHITECTURE.md`:179**, which types the prompt `PromptToken[]` — a 3×3
  matrix, a function machine, seven elastic tiles, two pair-cards and figurate SVGs are not a flat
  list. Variance lives inside an opaque payload, which is exactly what `ARCHITECTURE.md` §2
  permits ("no `oneOf`, no `discriminator`").
- **`AnswerSpec` is a closed union**: `(num, den)` for a fraction, an integer for series, matrix,
  analogy, hidden operation and figurate.
- **`PuzzleSpec` is a closed union** keyed by `PuzzleKind { kenken, kakuro, killer, magicSquare,
  wordSearch }` with an opaque per-kind payload. The pack carries boards, blocked cells, cages,
  targets, solutions, tutorial steps and reference-sheet content, because `f6-puzzles` promises
  *"plays fully offline"* while `CLAUDE.md` forbids generating a board on the client — and the
  format freezes here, three phases before that change.
- **`KeypadLayout` is a closed enum of `item`, `puzzle`, `otp`** (§5.3 D14) — no per-template
  keypad spec, no per-key list.
- **The `diagnosis` slot is reserved, versioned and nullable** and carries Q2's answer: per
  labelled distractor an `HMAC(canonical answer) → { misconception, steps, explain }`, plus one
  generic, non-scolding fallback per skill for the answer no distractor anticipated. The HMAC
  message construction freezes with the format, because it is a cross-stack contract
  (`ARCHITECTURE.md` §1) and `CLAUDE.md` names it as ours to write.
- **The pack declares skill-map node state** (§7.0 B). `SkillGraph` never derives it, which is what
  lets `f5-skill-map` ship before a mastery threshold exists.
- **`contract/` at the repo root** holds the committed artifacts: the emitted schema, one golden
  fixture per stimulus kind and per puzzle kind with their rejection rows, `canon.golden.json`, and
  the recorded normalisation of every fixture — the target `f1b-content-reader`'s `req-pack-parity`
  compares its Dart parser against.
- **CI gains the `contract` job** from `ARCHITECTURE.md` §8 (emit + `git diff --exit-code`), wired
  into `gate`; `.claude/hooks/verify-gate.sh` gains the new package; and the four documents that
  name the command set are reconciled in the same change (PROC-5, PROC-6, PROC-7).
- **One new runtime dependency, Zod**, with its DEP-1 audit stated: a schema library that makes no
  network call, reads no environment and ships no telemetry.
- No **BREAKING** change: nothing consumes this format yet.

## Non-goals

Scope that is not excluded gets built, so this is the list:

- **No Dart.** Not one file under `app/` is touched. That is what keeps this change parallel to
  the whole F0 Dart fan. The Dart parser and `req-pack-parity` belong to `f1b-content-reader`,
  which declares `Depends on: f0-pack-contract`; writing them here would be a cycle on the one
  change that must not slip.
- **No pack builder.** `f1-5-pack-builder` emits packs; this change defines what a pack is and
  hand-writes the fixtures.
- **No OpenAPI.** `packages/contract`'s OpenAPI emitter, `contract/openapi.json` and the `oasdiff`
  breaking-change step are `f1-contract-emitter`. The `contract` CI job added here is emit +
  `git diff --exit-code` only.
- **No content.** Eleven golden fixtures are the minimum that makes the format checkable, not a
  content set. Templates, generators and the es-MX copy pool are R3's work at F1 and F1.5.
- **No grading, no rating, no rederivation.** `packages/core` does not exist and is not created
  here.
- **No database, no migration, no endpoint, no deployment.**
- **No `protected-paths` CI job.** `contract/` becomes a protected path the day that job exists;
  adding it is `f3-store-artifacts`'s neighbourhood, not this change's.

## What this builds on, with paths

Brownfield, so the precedents are named rather than invented:

- `packages/server/src/routing.ts` versus `packages/server/src/adapters/http-server.ts` — the PURE
  split this package copies, and the reason `packages/server/test/routing.test.ts` runs with zero
  mocks.
- `packages/server/package.json` — the script set (`typecheck`, `test`, `verify`, `mutation`,
  `dry`), the `strict` + `verbatimModuleSyntax` tsconfig, and the fact that the package installs
  with **npm and its own `package-lock.json`**: `pnpm-workspace.yaml` declares a workspace and a
  `catalog:`, but pnpm is not installed on this machine, so the root scripts do not run.
- `.github/workflows/ci.yml` — the `changes` / `secrets` / `dart` / `ts` / `spec` / `gate` shape,
  and its header comment listing `contract` under *"Not implemented yet, deliberately"*, which this
  change makes false.
- `.claude/hooks/verify-gate.sh` — runs `npm run typecheck` and `npm test` in `packages/server`
  only, while its path filter fires on any `packages/` path.
- `docs/IMPLEMENTATION-PLAN.md` §4's `f0-pack-contract` block (lines 1302–1396) is the source of
  the requirements below; §7 Q2 and §7.0 B are the two decisions it must carry.
- Nothing under `app/lib/design/` is read or written by this change.

## Capabilities

### New Capabilities

- `offline-pack-format`: what an offline pack is — its version, its items, its stimulus payloads,
  its answer specs, its puzzles, its keypad layout, its diagnosis payload and its skill-map node
  states — plus the answer canonicalization both stacks share, frozen as committed artifacts with
  golden fixtures.

### Modified Capabilities

None. `openspec/specs/` is empty; this is the first capability in the repository.

## Impact

**New files**

- `packages/contract/**` — `package.json`, `tsconfig.json`, `vitest.config.ts`,
  `package-lock.json`, `src/**` (pure), `src/adapters/**` (the emit script), `test/**`.
- `contract/**` — the emitted schema, `contract/fixtures/**` (11 golden fixtures, their rejection
  rows and their recorded normalisations), `contract/fixtures/canon.golden.json`.

**Modified files**

- `.github/workflows/ci.yml` — a `contract` path filter, the `contract` job, `gate`'s `needs`, and
  the header comment that currently says `contract` has nothing to guard.
- `.claude/hooks/verify-gate.sh` — run the new package's checks, and the baseline note.
- `CLAUDE.md` — the Commands block and the "What exists today" list.
- `.claude/conventions/craftsmanship.md` — PROC-5's verbatim command block, which states outright
  that the rulebook, the hook and CI must name one set of commands.
- `openspec/config.yaml` — its `context:` block tells every future proposal that
  `packages/contract` does not exist (PROC-7).

**Dependencies**

- `zod`, pinned to an exact version rather than a caret range: a caret plus a byte-determinism gate
  means an unrelated `npm ci` turns CI red with no diff in the repository.
- DEP-1 audit: Zod makes no network request, collects nothing, and reads no environment. It is a
  schema library that runs in-process.

**Downstream**

- Unblocks `f1b-content-reader` and `f1-5-pack-builder`, and therefore both lanes.
- `f1-contract-emitter` inherits this package and adds the OpenAPI half.
- R2 and R2b in §6 lose their early signal: `contract/fixtures/` exists, with rejection rows.
