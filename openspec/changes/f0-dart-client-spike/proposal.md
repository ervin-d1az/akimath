# f0-dart-client-spike — Spike A

**Phase:** F0 (`ARCHITECTURE.md` §9, *"Scaffolding + two forking spikes"*, Spike A, ½ day).
This is the timeboxed spike that phase names; it is beside the critical path, not on it
(`docs/IMPLEMENTATION-PLAN.md`:2603-2604 — *"decides `app/lib/api/` shape only"*).

## Why

`CLAUDE.md`'s **Open decision** is still open: the Dart API client is
`swagger_dart_code_generator` versus **~250 hand-written lines**, and until it is decided
`app/lib/api/` must not be treated as generated-only. `ARCHITECTURE.md` §2 already wrote the
exit criterion — *"if the generated Dart for three representative schemas is not better than
what you would write by hand, write it by hand"* — and nobody has run it.

Now, because the decision is an **upstream of `f1-contract-emitter`**
(`docs/IMPLEMENTATION-PLAN.md`:1687), and because it decides whether three other things exist
at all: five codegen dependencies, `build_runner` in every worktree, and the
`git diff --exit-code` byte-determinism gate that `ARCHITECTURE.md` §2 hangs the whole
contract chain on. That gate is only real if the generator is byte-stable across two runs on
the same input; **nobody has checked**, and a CI job asserting a property the tool does not
have is worse than no job.

## What Changes

- **One new committed file: an ADR under `docs/adr/`** recording the decision, the evidence
  behind it, and its consequences. The directory holds only `.gitkeep` today, so this change
  also mints the ADR filename and heading convention (see `design.md`).
- **`CLAUDE.md`'s "Open decision" section is rewritten** to point at the ADR, because an open
  decision that has been decided and left open in the entry-point document is how the next
  session redoes this work (PROC-6).
- **`ARCHITECTURE.md` §2 is amended in the same session if — and only if — the evidence
  contradicts it.** Two clauses are at risk: *"the Dart client is committed; CI runs the
  generator and does `git diff --exit-code`"* (dead if generation is not deterministic, and
  dead by construction if the hand-written client wins) and the option space itself. Recording
  a finding and leaving the document asserting the opposite is a PROC-6 violation.
- **No product code.** Nothing under `app/lib/`, `app/test/`, `packages/server/src/` or
  `packages/server/test/` is touched, and `app/pubspec.yaml` / `app/pubspec.lock` come out of
  this change byte-identical. The spike's own throwaway code is built and deleted inside the
  change (`design.md`, Decision 2), so the repository's committed diff is documentation only.

## Capabilities

### New Capabilities

None. This change ships **no observable system behaviour**: its output is a recorded
decision, and a spec is a behaviour contract. `.openspec.yaml` therefore sets
`skip_specs: true`, which is the case the schema's own `specs` instruction enumerates
(*"pure refactor, tooling, docs"*) alongside its warning not to *"invent a requirement just to
satisfy validation"*. The ADR's acceptance conditions — that it exists, that it records the
§2 exit criterion against read code, and that it records the two-run byte comparison — are
carried as checkable tasks in `tasks.md`, so nothing verifiable is lost by skipping specs.

### Modified Capabilities

None. `openspec/specs/` is empty; no requirement anywhere changes.

## Non-goals

- **Writing the client.** Whichever side wins, `app/lib/api/` is an **F3** directory
  (`docs/IMPLEMENTATION-PLAN.md`:262). This change decides its shape and writes nothing into it.
- **Creating `packages/contract`.** That is `f1-contract-emitter`. The three Zod schemas here
  are throwaway spike inputs authored to be representative, not the beginning of the real
  contract package, and they are deleted with the rest of the scaffold.
- **Freezing the real API surface.** The three schemas stand in for 12–15 endpoints. Nothing
  here fixes an endpoint, a path or a field name.
- **Adding any dependency to `app/`.** Whatever the spike installs lives outside the Flutter
  package and leaves with it.
- **Re-litigating the removed options.** `dart-dio` and `openapi-generator-cli` both need a
  JVM, and `openapi-generator-cli`'s Docker image needs Docker. Neither is on this machine.
  The spike **records the commands that prove it** rather than repeating the claim (see
  `design.md`, Decision 4 — `command -v java` is not the check that proves it).
- **Deciding OpenAPI's version or its polymorphism posture.** 3.0.3 and *"zero response
  polymorphism"* are settled in `ARCHITECTURE.md` §2 and are **inputs** to the spike.

## What this builds on, on disk

- `ARCHITECTURE.md`:121-138 — §2, *The contract chain*: the option space, the exit criterion,
  the determinism gate. The authority this change answers to.
- `CLAUDE.md` — *Open decision* (the question) and *Layout* (`contract/openapi.json`,
  `packages/core`, `packages/contract`, `app/lib/api/` all listed as **planned, not on disk**).
- `docs/IMPLEMENTATION-PLAN.md`:1288-1298 — this change's block; §2.4:262 places `api/` at F3;
  §5.4:2582,2603-2604 places the spike beside the critical path.
- `docs/adr/` — exists, contains only `.gitkeep`. The destination.
- `app/pubspec.yaml` — the file this change must leave untouched: today `flutter`,
  `cupertino_icons`, `meta` at runtime, and no `build_runner`.
- `packages/server/` — the only TypeScript package that exists; it has no `dependencies` key,
  so Zod is not installed anywhere in the repo today.

## Impact

- **Documentation:** `docs/adr/<the ADR>` (new), `CLAUDE.md` (Open decision → decided),
  `ARCHITECTURE.md` §2 (amended only if contradicted).
- **Downstream changes:** `f1-contract-emitter` declares this spike as an upstream
  (`docs/IMPLEMENTATION-PLAN.md`:1687) and inherits its answer — whether the emitter's output
  feeds a generator or a hand-written client, and whether CI grows a byte-diff job.
- **Dependencies:** possibly **minus five**. The hand-written outcome deletes
  `swagger_dart_code_generator`, `build_runner`, `json_serializable`, `json_annotation` and
  `dio` from the project's future, along with `build_runner` from every worktree. Nothing is
  added to `app/pubspec.yaml` either way by this change. DEP-1 still applies to what the
  spike installs in its throwaway workspace, and the ADR states the network-call audit for
  each candidate dependency even for the ones that do not survive — the audit is what makes
  the option admissible at all, and it has to be on the record before a later session
  re-proposes one from memory.
- **CI:** no job is added here. Whether `.github/workflows/ci.yml` ever gains a `contract`
  job that runs the generator and diffs bytes is exactly what this spike decides.
- **Evidence tier:** this change reaches **no tier**, and that is the honest outcome, not a
  skipped step. PROC-5's Tier 1 commands are unaffected because no code under test changes —
  they are run to prove that (34 Flutter tests, 3 TypeScript tests, both analyzers clean) and
  the numbers go in the ADR. Tier 1b has no logic to falsify; Tier 2 has nothing to exercise.
