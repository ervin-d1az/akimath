## Context

See `proposal.md` — Why. The constraints that shape the approach:

- `packages/core` states **zero runtime dependencies** in its own header and enforces it by reading
  its manifest (`test/dependency-allowlist.test.ts`). The builder needs `answerDigest` and
  `parsePack`, both of which live in `packages/contract`.
- `packages/core` bans ambient IO by walking the AST (`test/determinism.test.ts`) — no clock, no
  randomness. A builder that chose its own seeds would violate the package's central property.
- `packages/core` ships exactly one template, `arith.integer.subtract`. The app draws six families.
- The frozen validator demands per-item `skill_id`, `keypad` and a digest answer, and demands every
  `skill_id` have both a `skill_nodes` entry and a `skill_fallbacks` entry.
- A spike lifted all 70 authored items into the frozen envelope and `parsePack` returned `ok`, with
  no change to any item's content. The lift is therefore an envelope problem, not a content problem.

## Goals / Non-Goals

**Goals:**

- Make `packages/core` load-bearing, with the pack the thing that carries its output.
- Keep the app at six families throughout — no slice of this work may regress what a player sees.
- Keep every property `packages/core` currently claims true, or change it deliberately and say so.

**Non-Goals:**

- Teaching the app to read the emitted pack. That needs HMAC in Dart and a DEP-1 audit for
  `package:crypto`; it is a separate decision and a separate change.
- Writing templates for the other five families. Each is its own change once the builder exists.
- Any change to the frozen pack format, the schema, or the retention figures.

## Decisions

### D1 · The builder is dev tooling, so `@akimath/contract` stays a devDependency

The alternatives were to promote contract to a runtime dependency of core, to move the builder into
`packages/contract` (inverting the dependency and making the format package know about templates),
or to add a fourth workspace package.

Promoting it would falsify a documented, tested property of `core` for the benefit of a tool that
never ships to a device. A fourth package would duplicate a Stryker config, a jscpd config, a
vitest config and a lockfile to hold two files. Inverting the direction would put template
knowledge in the package whose job is to be the frozen shape both stacks read.

So the builder lives in `packages/core` — `src/pack/` for the pure assembly and
`src/adapters/build-pack.ts` for the CLI — and contract remains a **devDependency**, which it
already is.

**This is only honest if the exported surface never reaches contract**, so it becomes a gate rather
than a convention: a test walks the transitive imports of `src/index.ts` and fails if any of them
resolves into `@akimath/contract`. Without it, "zero runtime dependencies" degrades from a checked
fact to a comment, which is exactly the failure mode `core` was built to avoid.

### D2 · A build is declared in data, and a source is a template invocation or an authored file

The builder takes a **declaration** — seed base, pack salt, validity window, and an ordered list of
sources — rather than hardcoding what to build. A source is either `{template, version, ladderStep,
count}` or `{authored, path}`.

This is what keeps the app at six families without special-casing anything: the five families core
cannot generate arrive as authored sources, and each one becomes a template invocation later by
editing the declaration. It also keeps the authored items in exactly one place — the file the app
already ships — because the path is data. A copy inside `packages/core` would be a second source of
truth for content a person edits by hand, and the two would drift.

The alternative, generating everything and accepting one family, was rejected outright: it makes the
product worse to make the architecture tidier.

### D3 · Seeds are a counter from a declared base

`TemplateRef.seed` is a signed `bigint`. The builder derives the *n*th generated item's seed as
`base + n`, with `base` an argument.

A clock- or random-derived seed would make the pack unreproducible, which forecloses the byte-diff
gate — and `Math.random()` and `Date.now()` are already AST-banned in this package. `splitmix64`'s
counter-linearity means consecutive seeds still produce well-distributed items, so a counter costs
nothing in item quality. Declaring the base rather than fixing it at 0 lets a future pack be
regenerated as a different draw without changing code.

### D4 · Diagnosis copy is authored in its own file, keyed by misconception

Distractor copy is Spanish prose about a specific mistake. Putting it in TypeScript beside the
assembly logic would mean a copy edit is a code review, and would make the eventual translation
pass a search through source files.

So the copy lives in a data file keyed by misconception id, and a distractor names the misconception
it is an instance of. The frozen `DiagnosisCopySchema` already requires `misconception` to be a
snake_case identifier, so the format anticipated this.

### D5 · The emitted pack is a committed artifact, gated the way the others already are

`canon.golden.json`, the OpenAPI document and `packages/core/golden/` are all emitted, committed and
byte-diffed in CI. The pack joins them, using the same staged-diff form — `git add -A` before
`git diff --cached --exit-code` — because a bare `git diff` is blind to an artifact the author never
committed.

### D6 · The builder writes through a temporary file

Output goes to a temp path and is moved into place only after the frozen validator has accepted it.
This is not speculative: `scripts/dump-schema.sh` truncated its output before its producer had run,
and a failed dump destroyed the committed snapshot. The same shape would do the same thing here.

## Risks / Trade-offs

- **The lift is proven for today's 70 items, not for items nobody has written yet** → the lift test
  runs over the shipped authored file rather than a fixture copy, so a newly authored item that
  cannot be lifted fails the build rather than being discovered later.
- **Two formats coexist**: the app reads its own, the builder emits the frozen one → deliberate and
  time-boxed to the follow-on change that adds the Dart reader. The risk is that they drift in
  content; the lift test reads the app's real file, so drift shows up as a failure rather than as
  two packs quietly disagreeing.
- **Distractor copy is the long pole and it is authored, not generated** → `diagnosis` is nullable
  in the frozen format, so the builder can emit valid packs while the copy is still being written,
  and it reports how many items lack it so the gap stays visible rather than being assumed closed.
- **A counter seed means two packs built from the same base share items** → intended for now, since
  reproducibility is worth more than novelty while there is one template; the base is an argument
  precisely so this is a choice rather than a property.
- **`core` gaining a CLI puts a second adapter beside `emit-golden.ts`** → both stay out of the
  mutation-testing scope, which already excludes `adapters/`, so neither dilutes the score that
  makes the pure half trustworthy.

## Migration Plan

None. The change adds an artifact and a command; it removes nothing and alters no format. The app is
untouched, so there is nothing to roll back on a device. Reverting the change is deleting the emitted
pack and the CI step that diffs it.
