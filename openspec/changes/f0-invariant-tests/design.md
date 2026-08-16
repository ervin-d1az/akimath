## Context

See `proposal.md` — Why. The constraints that shape the approach, and nothing else:

- `app/lib/design/tokens/tokens.dart` holds **three `export` directives and no `import`**. The edge
  to `package:flutter/painting.dart` sits one file further in, at `brand_typography.dart:1`. A
  one-hop resolver reports zero; a resolver that follows `import` alone reports zero at any depth.
  This single file dictates the closure's shape (plan §2.2).
- The roots the gate scans **mostly do not exist yet**. `design/**/spec/` has exactly one directory
  (`design/brand/spec/`, two files); `features/*/policy/` and `content/model/` arrive in later
  changes. A gate that is silent on an absent root and silent on a present-but-unscanned root is
  indistinguishable from a gate that works.
- Three of the six transcribed scenarios describe **states that cannot exist on disk without
  breaking the build**, which is what forces the resolver's shape. See D-1.
- `app/test/design/no_blurred_shadow_test.dart:65-74` pumps at 2400×4000 and says why in its own
  comment: the character sheet "lays out full-width cards side by side, so it needs a surface big
  enough to render without overflowing into an unrelated failure."
- PURE-1's decisive test applies here verbatim: *if proving the decision correct requires faking a
  canvas, a socket, a clock or a seed, the decision is on the wrong side of the boundary.* Proving
  the closure correct must not require creating a real violation on disk.

## Goals / Non-Goals

**Goals (design-level, beyond the proposal's scope statement):**

- Every gate in this change is falsifiable without editing `app/lib/` — a reviewer can see it bite
  by feeding it a graph, not by breaking the repository.
- One place to register a screen, not two.
- Each known blind spot is written into the code that has it, so it is read as a limit rather than
  discovered as a bug.

**Non-Goals (design-level):**

- No general-purpose Dart import analyser. This is a directive-level textual scan with stated
  limits, not a resolved element model.
- No configuration file, no YAML, no rule DSL. The roots and the allowlist are Dart constants in
  the test tree, versioned with the tests that use them.

## Decisions

### D-1 · The resolver is pure and takes a source map; the filesystem is an adapter beside it

**PURE side:** `app/test/architecture/import_graph.dart` — **pure** (PURE-1). It takes
`Map<String, String>` of canonical-uri → source text and returns violations and cycles. No
`dart:io`, no `Directory`, no `File`.
**Adapter side:** `app/test/architecture/source_tree.dart` — **PURE-2 adapter**. It walks
`app/lib/`, reads bytes, and returns that map. It decides nothing; the root list it walks is data it
is handed.
`pure_boundary_test.dart` is the only place the two meet.

This is not stylistic. The scenarios *require* it. "A `policy/` file imports the barrel" and
"`home` imports `shell/shell.dart` while `shell` imports `home/home.dart`" describe a repository
that does not compile — and no `features/*/policy/`, `features/home/` or `features/shell/` exists
today. Writing those files to disk to exercise the gate would be both an intentionally broken build
and an ordering edge into F2, which is exactly what the plan avoided when it moved the progress-dots
scenario out of this change (plan lines 1016-1021). With a pure resolver, those scenarios are
**synthetic graphs handed to a function** and they go red or green on logic alone.

**Which scenarios are real and which are synthetic — stated so a BUILD agent does not create files:**

| Scenario | Fed how |
|---|---|
| The token barrel is caught transitively | synthetic graph containing a fictitious `policy/` file, plus the **real** `tokens.dart` / `brand_typography.dart` sources read from disk |
| The closure follows exports, not only imports | **real** — the resolver walks the actual `app/lib/design/tokens/tokens.dart` |
| An ambient clock is caught | synthetic source string |
| A commented-out import is not a violation | synthetic source string |
| The gate is not vacuously green | **real** — counts over the actual tree |
| Two features import each other's barrel | synthetic graph. **No `home.dart` or `shell.dart` is written to disk.** |
| A screen that fits at 1.0 and not at 1.3 | a deliberately-overflowing fixture screen declared inside the test. `04 Error` is `f2-core-loop`; naming it here would be a cycle |

*Alternative considered:* an analyzer plugin or `custom_lint`. Rejected on DEP-1 (a new dependency
to audit for something a 150-line pure function does), on PROC-5 (the rulebook already records
`dart_code_linter` as a tool that "can only ever be green" because nothing configures it — a second
unconfigured analyser is the same trap), and because a plugin's findings are not a red `flutter
test`, which is what the hook and CI actually run.

*Alternative considered:* a shell script with `grep` in `verify-gate.sh`. Rejected: it cannot do a
transitive closure, it is not covered by `flutter test`, and it has no failing-test-first form.

### D-2 · Canonical URIs, and where the walk stops

Repo-local directives arrive in two spellings — relative (`../tokens/tokens.dart`) and
`package:akimath_app/design/tokens/tokens.dart`. The resolver normalises both to one key, the path
relative to `app/lib/`, so the two spellings cannot hide the same edge from each other.

The walk stops at, and never resolves, `dart:` URIs and third-party `package:` URIs. They are
**leaves that carry a verdict**: `dart:ui`, `dart:math`, `dart:core` and `package:meta` are allowed
by plan §2.2; everything under `package:flutter/`, `dart:io` and `dart:async` is a violation; any
other `package:` is a violation because §2.2's Packages row allows `package:meta` and nothing else.

*Alternative considered:* resolving into `.pub-cache` for a true closure. Rejected — slow, machine
dependent, and pointless: a third-party package's internals cannot make an allowed package
forbidden.

### D-3 · `dart:async` stays on the list and is documented as toothless

Plan §2.2 forbids `dart:async` in `policy/`, so it stays on the allowlist's wrong side — it costs
one entry in a list the closure already walks. But it **bans nothing useful**: `Future` and `Stream`
come from `dart:core` (plan lines 1094-1096). If the intent is *policy does not wait*, the check is
for `async` / `await` / `Future<` in the body — and that check is a **Non-goal here** (see
`proposal.md`), because no scenario covers it and an untested check in a gate is worse than a
documented gap.

### D-4 · The ambient scan is textual, and its three blind spots are written into the file

Patterns: `DateTime.now(`, `Random(`, `Platform.` — exactly §2.2's Ambient row. Comments are
stripped first, or `// import 'package:flutter/…'` is a false positive (plan lines 1091-1092); that
strip earned the one scenario added beyond the plan's six.

Stated limits, to be carried as a doc comment on the scan so they are read as limits:

- It does not see `Random.secure()`, a `DateTime.now` tear-off, or a clock reached through an alias.
- A `now` **parameter** is not a blind spot — it is **the shape §2.2 wants**: `remainingCooldown(issuedAt, now)`
  takes the clock as a value, and the widget in `ui/` reads it. Injected as values, not as interfaces.
- String literals are not stripped, so a string containing the literal text `DateTime.now()` would
  be a false positive. Accepted; if it ever bites, PROC-6 says fix it in that session.

### D-5 · One screen registry, shared by both gates — a deviation from §4's definition of done, named

`app/test/design/screen_registry.dart` holds one list of entries: a label, a builder, and the
viewports the screen must survive. `no_blurred_shadow_test.dart` and `screen_overflow_test.dart`
both read it.

Plan §4's definition of done lists points 1 and 2 as two separate registrations. This collapses them
into one. **The deviation is the point:** two hand-maintained lists of ~50 screens rot at different
rates, and the plan itself calls the definition of done "the first thing that silently rots."

*Alternative considered:* leave the two lists separate, exactly as written. Rejected for the reason
above, but it is a cheap reversal if Ervin prefers the plan verbatim.

**This does not collide with D22.** `f0-dashed-border` amends `no_blurred_shadow_test.dart` by
adding **assertions** — painter coverage — not by adding screens. It reads the registry the same way
after this change as it would have read the map before it.

### D-6 · An exemption is data with a reason, and it is granted only after the gate goes red

The registry's viewport set is per-screen, and any screen that does not carry the full
390×844 × {1.0, 1.3} set carries a reason string next to it. Nothing is exempted in advance:

- **`character_sheet` is not pre-exempted.** §2.6 says it is a brand inspector and not a product
  screen, and `no_blurred_shadow_test.dart`'s own comment says it needs a large surface — but it is
  a `ListView` (no vertical overflow) and `RenderWrap` reports no overflow error, so it may simply
  pass. A pre-baked exemption for a screen that passes is dead configuration a reviewer has to
  disprove, and it is how a gate becomes green-by-construction. Run it; exempt only what is actually
  red; write the reason.
- **`splash` gets no standing exemption.** If either variant overflows at `textScaler` 1.3, the fix
  is the screen, in this change. A screen that breaks for a child with large text is the first real
  defect this gate catches, and excusing it permanently would make `req-screen-overflow` cover zero
  product screens — the `dart_code_linter` failure mode PROC-5 already names. This is the one
  product-code edit this change may make, and it is flagged for approval rather than assumed.

The order this forces is in `tasks.md` 3.3 → 3.4 and it is not stylistic: `.claude/hooks/verify-gate.sh`
exits 2 on a red `flutter test`, so no commit may end red. The gate is therefore **run before it is
committed**, each entry lands at the set its screen actually survives, and a reason string quotes
the overflow message that earned it. A `splash` reason string is a marker with a lifetime of exactly
one task — 3.4 deletes it — while the `character sheet` one, if it is earned, is permanent and cites
§2.6.

### D-7 · Non-vacuity is per root and conditional on existence

The gate reports `<root> → n files` for each root and fails when `n == 0` **for a root that exists
on disk**. An absent root (`features/*/policy/`, `content/model/` today) is reported as absent, not
counted, not failed. That is what lets the gate ship first and stay honest as the tree fills in.

## Risks / Trade-offs

- **The gate ships covering almost nothing.** Today one root exists with two files, and the closure
  finds no violation because no `policy/` exists → the whole point of D-7's per-root counts and of
  the Tier 1b falsification step in `tasks.md`. The counts are printed so a reader sees the coverage
  rather than inferring it from green.
- **`splash` may go red at 1.3 and pull product code into a planning-scoped change.** → D-6; the
  branch is named in the tasks and surfaced to Ervin rather than resolved by exemption.
- **A directive-level scan can be fooled** — a string literal, a `part` file, conditional imports
  (`if (dart.library.io)`). → D-4 writes the limits into the file; `part`/`part of` directives are
  followed as repo-local edges so a `part` cannot smuggle an import past the closure.
- **Two hundred files × a full closure per test run** could get slow. → the closure is computed once
  per run over a cached source map, not once per root; at 18 files today it is unmeasurable, and if
  it ever is, the cache is the lever.
- **The registry is still hand-maintained**, just once instead of twice. A screen nobody registers
  has no coverage. → §4's definition of done is the process guard; there is no way to enumerate
  screens automatically without reflection.

## Open Questions

- Should the overflow gate also pump at a small-phone width (360×640) once real screens exist? Not
  answerable now and it changes no spec, no approach and no task — the registry's per-screen
  viewport set is the seam that makes it a one-line addition later.
