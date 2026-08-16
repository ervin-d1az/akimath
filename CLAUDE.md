# AkiMath

Adaptive math challenges in Mexican Spanish, with a dog called Aki. Flutter client,
TypeScript backend, Postgres on Neon (planned). One repository — see
[ARCHITECTURE.md](ARCHITECTURE.md) §1 for why.

**Audience includes children under 13** (Mexico and Spanish-speaking LatAm, decision #1).
That is an engineering constraint, not a marketing note: no third-party SDK that collects
data, no ads, no external analytics. Before adding *any* dependency, check whether it phones
home; if it does, it does not go in. Today that constraint holds by construction — `app/`
ships `flutter`, `cupertino_icons` and `meta` at runtime, `packages/server` has no
`dependencies` key at all, and `packages/contract` has exactly one: `zod`, pinned to an
exact `4.4.3` because the pack determinism gate is byte-for-byte.

**Code, identifiers, comments and docs are in English.** Only end-user-visible text is in
es-MX.

## Layout

```
app/                      the Flutter client — the only Dart package
  lib/design/brand/spec/   pure geometry: no Canvas, no widgets, testable without mocks
  lib/design/brand/        the adapter that paints that spec
  lib/design/tokens/       colors, type, shape. No color literal lives outside tokens/
  lib/features/            screens
  test/architecture/       import-graph and literal gates: pure predicates + one SourceTree adapter
packages/server/          @akimath/server — pure `routing.ts`, IO in `adapters/`
packages/contract/        @akimath/contract — the offline pack format, pure; emitter in `adapters/`
contract/                 the frozen artifacts: 3 schemas, 37 fixtures, canon.golden.json
docs/adr/                 ADR 0001 decides the Dart API client; older decisions live in ARCHITECTURE.md
```

Planned, **not yet on disk** (README's layout block describes the destination, not the
present): `contract/openapi.json`, `packages/core` (`@aki/core`, zero dependencies),
`app/lib/api/`. `packages/contract` now exists and holds the offline pack format; its
OpenAPI half arrives with `f1-contract-emitter`.

## What exists today

- **Built and tested.** The brand layer and Aki's character sheet: tokens, wordmark, app
  icon, three poses, the splash screen. 135 Flutter tests, green.
- **A scaffold.** `packages/server` routes one endpoint, `GET /health`, through a pure
  `route()` function. 3 tests, green, 100% mutation score.
- **The offline pack format, frozen.** `packages/contract` (`@akimath/contract`) holds the
  pack schema, the answer canonicalizer, the HMAC digest and the puzzle validators — all
  pure, with the emit script as the one adapter. `contract/` holds what it emits: the
  schemas, one golden fixture and one rejection row per stimulus and puzzle kind, their
  recorded normalisations, and `canon.golden.json`. 189 tests, green, 91.71% mutation score,
  0 clones. **Zod 4.4.3 is the repository's first runtime dependency**, pinned exactly
  because the determinism gate is byte-for-byte.
- **Does not exist.** No database, no migrations, no auth, no API endpoints beyond health,
  no dev environment, no deploy. Item generation, the math compositor, the keypad and the
  pack *builder* are all unwritten — the pack *format* is frozen, the packs are not built.
- **CI exists, narrowed to the code that exists.** `.github/workflows/ci.yml` runs `changes`,
  `secrets` (gitleaks), `dart` (`flutter analyze --fatal-infos`, `flutter test`), `ts`
  (`npm run typecheck`, `npm test` in `packages/server`), `contract` (the same two in
  `packages/contract`, then `npm run emit`, `git add -A -- contract/` and
  `git diff --cached --exit-code -- contract/` — staged, because a bare `git diff` is blind to
  an artifact the author never committed), `spec` and `gate`.
  ARCHITECTURE.md §8's other jobs — protected-paths, compliance, integration, mutation — are
  deliberately absent because the code they guard does not exist; `contract`'s own `oasdiff`
  half waits on `f1-contract-emitter`. `gate` is the intended required check and is **not
  registered on the `protect-main` ruleset yet**, so today CI is advisory on `main`.
- **The workspace is declared but not live.** The root `package.json` names
  `pnpm@11.21.0` and `pnpm-workspace.yaml` carries a `catalog:`, but pnpm is not installed
  and `packages/server` still pins its own `typescript@^5.7.2` against the catalog's
  `^6.0.3`. **The root scripts do not run.** Use the per-stack commands below.

Work is tracked by the phase vocabulary in ARCHITECTURE.md §9 (`F0`…`F8`). There is no
ticket tracker. We are in **F0**.

## Commands

```sh
# Flutter — from app/
flutter analyze --fatal-infos
flutter test

# TypeScript — from packages/server/
npm run verify        # tsc --noEmit && vitest run
npm run mutation      # Stryker over src/, excluding main.ts and adapters/
npm run dry           # jscpd duplication

# TypeScript — from packages/contract/
npm run verify        # tsc --noEmit && vitest run
npm run mutation      # Stryker over src/, excluding adapters/
npm run dry           # jscpd duplication
npm run emit          # rewrite contract/; the tree must not move afterwards
```

`flutter analyze --fatal-infos` + `flutter test` + `npm run verify` **in both TypeScript
packages** are the everyday gate, and
they are the *enforced* gate: `.claude/hooks/verify-gate.sh` runs them on every `git commit`
and `git push` and exits 2 (blocking) on a failure, and `.github/workflows/ci.yml` runs the
same commands — both spell the TypeScript half as `npm run typecheck` then `npm test`, which is
what `npm run verify` chains. Run `--fatal-infos` locally or the hook will surprise you.
Mutation and jscpd are the deeper pass (tier 1b below), run when the logic under change is
worth them.

Two tools are installed but are **not commands here**: `dart run mutation_test` has no rules
XML, and `dart run dart_code_linter:metrics analyze lib` reports nothing at all because
`app/analysis_options.yaml` carries no `dart_code_linter:` block — it is green by
construction, so it is not evidence until someone configures it.

## Workflow

TDD, clean code and clean architecture are requirements here, not preferences. Red → green →
refactor; the test is seen failing first. One small, logical commit per coherent change.

Planning runs on [OpenSpec](https://openspec.dev). A unit of work is a **change**, its id is the
change name, and its plan is committed to `openspec/changes/<change-id>/` rather than left in a
scratch directory — so the plan a reviewer reads later is the plan that was approved.

| Phase | One line | Owner |
|---|---|---|
| SPEC | `/opsx:explore` to think, `/opsx:propose` to write. Output is `proposal.md`, `design.md`, `tasks.md` and delta specs whose `#### Scenario:` blocks are the acceptance criteria. **Human approves the proposal before any code.** | main session |
| BUILD | Implement one task from `tasks.md`, test-first, against those scenarios. | `craftsman-engineer` |
| REVIEW | Conventions pass over the diff, citing rule IDs. | `craftsman-reviewer` |
| BUG HUNT | High-severity correctness only, each finding with a concrete trigger. | `craftsman-bug-hunter` |
| EVIDENCE | State the tier reached. | see below |
| LAND | Commit and push only when asked. | main session |
| ARCHIVE | `/opsx:archive`, only after the pull request has merged. | main session |

There is no DEPLOY phase: there is nothing to deploy to.

`/opsx:propose` will not touch project code — the approval gate is enforced by the tool, not by an
agent's restraint. Read the plan back with `openspec show "<change-id>"` and check the gate with
`openspec status --change "<change-id>" --json`; both read disk, which is the point. Project-wide
conventions reach every proposal through `openspec/config.yaml`, so edit that file rather than
repeating the rules in each one.

**Evidence tiers.** Three names, used identically in this file, in the rulebook and in every
agent — if you find a fourth numbering somewhere, that file is wrong.

- **Tier 1 — the committed suite.** The everyday-gate commands above, with the numbers stated.
- **Tier 1b — show the tests bite.** `npm run mutation` (Stryker) and `npm run dry` on the TS
  side; on the Dart side, with no mutation harness configured, a falsification step (see the
  rulebook's PROC-5 for the mechanism, which is not optional — it edits versioned code).
- **Tier 2 — exercise the real thing.** The app run on a device or simulator when the change
  surfaces visually, or the endpoint called for real once endpoints and an environment exist.

"It compiles" and "it should work" are not evidence. Skipping a tier silently is a violation;
asking to skip one is not.

Detail lives in `.claude/agents/`. The rulebook the reviewer cites is
`.claude/conventions/craftsmanship.md` — **this file wins if the two ever conflict**, and the
rulebook gets corrected.

## Architecture rule

**Pure policy separated from IO.** Policy is a function of its inputs with no Canvas, no
socket, no clock and no environment, so it is testable without mocks; the adapter next to it
does the touching. Both precedents are already on disk: `app/lib/design/brand/spec/` versus
the painter beside it, and `packages/server/src/routing.ts` versus
`packages/server/src/adapters/`. New logic follows the same split. On the Dart side the split
is now a red build rather than a precedent: `app/test/architecture/pure_boundary_test.dart`
walks the import graph transitively — through `export` and `part`, so the tokens barrel cannot
smuggle `package:flutter/painting.dart` into a pure root — and reports a per-root file count so
a mistyped root cannot make it vacuously green. Today that bites over `design/**/spec/` and its
2 files; `features/*/policy/` and `content/model/` are declared roots with nothing in them yet,
and the gate reports them as absent rather than as passing.

## Invariants — do not break without discussing it

**Enforced by a test:**
- Coral (`#FF8A5B`) is error and nothing else; green (`#5ED6A4`) is action and success and
  nothing else; pink is never `error`, `success` or `action` — it is the accent, and
  `BrandColorRole.focus` is an input affordance, not a verdict.
  (`test/design/tokens/brand_colors_test.dart`)
- No blurred shadow, no gradient, no Material elevation. Shadows are hard, blur is always
  zero. (`test/design/no_blurred_shadow_test.dart` walks every screen and asserts exactly
  four things: no gradient, `blurRadius == 0`, `spreadRadius == 0`, and elevation 0 on
  `PhysicalModel` and `PhysicalShape` — add new screens to
  `app/test/design/screen_registry.dart`, which both this gate and `screen_overflow_test.dart`
  read.)
- Every registered screen fits 390x844 at `textScaler` 1.0 and 1.3.
  (`test/design/screen_overflow_test.dart`; the screen list is `test/design/screen_registry.dart`,
  and a viewport can only be excused by an `excused` entry quoting the overflow message that
  earned it.)
- No colour literal outside `app/lib/design/tokens/`, and no `Offset(` literal on a widget
  surface. (`test/architecture/no_color_literal_test.dart` scans all of `app/lib/` except
  `design/tokens/` for `Color(0x`, `Color.fromARGB(`, `Color.fromRGBO(` and `Colors.` — the last
  on a word boundary, since `Colors.` is a substring of `BrandColors.`; `Colors.transparent` is
  the one carve-out. `test/architecture/no_geometry_literal_test.dart` scans `design/widgets/`
  and `features/` for `Offset(`; `design/brand/` is out of scope as the artwork layer, and radii
  and border widths are not scanned at all. Both report how many files they scanned and fail at
  zero.)

**Encoded as a constant, not yet enforced:**
- Minimum touch target 48 px, keypad keys and board cells included
  (`BrandShape.minTouchTarget`).
- Success and error must be distinguishable by **shape**, not only hue — deuteranopia
  collapses green and coral. `BrandColorRole` still exposes `.color`; ARCHITECTURE.md §6
  wants a `Verdict` type on top that does not.

**Design intent, no code yet to enforce it:**
- Aki has exactly one body part that can be lost and come back: **the curl of her tail**. She
  does not scold, does not look disappointed, and does not appear while you are solving.
- No visible timer. Time is measured quietly.

**System invariants for the parts not yet built** (verbatim from ARCHITECTURE.md §4–§5):
- *The prompt travels rendered. The answer never travels online. Offline, a membership
  verifier travels and its verdict is provisional until sync.*
- *`attempts` never accepts UPDATE. It accepts DELETE only through the erasure path
  (`DELETE /v1/me`) and the retention job, both under the `retention_job` role. The request
  path holds no DELETE grant on `attempts`.*
- Rating never runs in Dart. Offline difficulty is fixed by the pack's `ladder_step`.

## Never

- Never add a dependency that collects data, serves ads, or reports analytics.
- Never use `BackdropFilter`. Nothing in `app/lib/` uses one today and no test asserts its
  absence, so this is intent the reviewer enforces by reading, not a red build.
- Never write a color literal outside `app/lib/design/tokens/` — every hue comes from
  `BrandColors`, and state comes from `BrandColorRole`. (`Colors.transparent`, used to switch
  Material's tinting off, is the one exception on disk.)
- Never use a LaTeX library to render math, or the system keyboard for numeric entry.
- Never hand-write authentication crypto — that is Better Auth's job. (HMAC message
  construction for offline verification is ours, and is a cross-stack contract.)
- Never generate puzzles on demand; they go in batches.

## Git

Commit email is `geineryodan@gmail.com` — verify `git config user.email` before committing.

`dev` is the working branch and **pushing to it is authorized**. `main` is protected by the
`protect-main` ruleset: no direct push, no force-push, no deletion — it is reached through a
pull request. Nothing is committed or pushed unless you were asked to.

## Decided

**The Dart API client is hand-written** — `docs/adr/0001-dart-api-client.md`, decided
2026-08-16 by the F0 spike `f0-dart-client-spike`. `swagger_dart_code_generator` is rejected:
its output fails `flutter analyze --fatal-infos` (3 `unused_import` warnings, under files that
open with `// ignore_for_file: type=lint` and so opt themselves out of the lint set), collapses
optional and nullable into one Dart shape and serializes an absent optional as `null`, silently
absorbs unknown enum values via a synthetic `swaggerGeneratedUnknown`, silently defaults a
missing **required** array to empty, and costs 14 net-new runtime packages against a floor of
zero. It won one rubric row of six — its output is byte-identical across cold runs — which is
not enough under §2's asymmetric criterion.

`app/lib/api/` is therefore hand-written, is an **F3** directory, and is a PURE-2 adapter that
holds no decisions. No `build_runner`, and no CI byte-diff job. The ADR carries a supersede
threshold (600 lines, 15 endpoints, response polymorphism, or auth/pagination/error envelopes),
so this reopens on evidence rather than on memory.
