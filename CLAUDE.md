# AkiMath

Adaptive math challenges in Mexican Spanish, with a dog called Aki. Flutter client,
TypeScript backend, Postgres on Neon (planned). One repository — see
[ARCHITECTURE.md](ARCHITECTURE.md) §1 for why.

**Audience includes children under 13** (Mexico and Spanish-speaking LatAm, decision #1).
That is an engineering constraint, not a marketing note: no third-party SDK that collects
data, no ads, no external analytics. Before adding *any* dependency, check whether it phones
home; if it does, it does not go in. Today that constraint holds by construction — `app/`
ships `flutter`, `cupertino_icons` and `meta` at runtime, and `packages/server` has no
`dependencies` key at all.

**Code, identifiers, comments and docs are in English.** Only end-user-visible text is in
es-MX.

## Layout

```
app/                      the Flutter client — the only Dart package
  lib/design/brand/spec/   pure geometry: no Canvas, no widgets, testable without mocks
  lib/design/brand/        the adapter that paints that spec
  lib/design/tokens/       colors, type, shape. No color literal lives outside tokens/
  lib/features/            screens
packages/server/          @akimath/server — pure `routing.ts`, IO in `adapters/`
docs/adr/                 empty; decisions currently live in ARCHITECTURE.md
```

Planned, **not yet on disk** (README's layout block describes the destination, not the
present): `contract/openapi.json`, `packages/core` (`@aki/core`, zero dependencies),
`packages/contract` (Zod + OpenAPI emitter), `app/lib/api/`.

## What exists today

- **Built and tested.** The brand layer and Aki's character sheet: tokens, wordmark, app
  icon, three poses, the splash screen. 34 Flutter tests, green.
- **A scaffold.** `packages/server` routes one endpoint, `GET /health`, through a pure
  `route()` function. 3 tests, green, 100% mutation score.
- **Does not exist.** No database, no migrations, no auth, no API endpoints beyond health,
  no dev environment, no deploy. Item generation, the math compositor, the keypad and
  offline packs are all unwritten.
- **CI exists, narrowed to the code that exists.** `.github/workflows/ci.yml` runs `changes`,
  `secrets` (gitleaks), `dart` (`flutter analyze --fatal-infos`, `flutter test`), `ts`
  (`npm run typecheck`, `npm test`) and `gate`. ARCHITECTURE.md §8's other jobs —
  protected-paths, contract, compliance, integration, mutation — are deliberately absent
  because the code they guard does not exist. `gate` is the intended required check and is
  **not registered on the `protect-main` ruleset yet**, so today CI is advisory on `main`.
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
```

`flutter analyze --fatal-infos` + `flutter test` + `npm run verify` are the everyday gate, and
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
`packages/server/src/adapters/`. New logic follows the same split.

## Invariants — do not break without discussing it

**Enforced by a test:**
- Coral (`#FF8A5B`) is error and nothing else; green (`#5ED6A4`) is action and success and
  nothing else; pink never carries state. (`test/design/tokens/brand_colors_test.dart`)
- No blurred shadow, no gradient, no Material elevation. Shadows are hard, blur is always
  zero. (`test/design/no_blurred_shadow_test.dart` walks every screen and asserts exactly
  four things: no gradient, `blurRadius == 0`, `spreadRadius == 0`, and elevation 0 on
  `PhysicalModel` and `PhysicalShape` — add new screens to its list.)

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

## Open decision

The Dart API client is a fork in the road, not a settled rule (ARCHITECTURE.md §2):
`swagger_dart_code_generator` versus ~250 hand-written lines. Until an F0 spike decides it,
do not treat `app/lib/api/` as generated-only.
