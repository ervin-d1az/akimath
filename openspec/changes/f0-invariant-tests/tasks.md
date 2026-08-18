Read `design.md` first — D-1's table says which scenarios are fed synthetic graphs and which read
the real tree. **No task below creates `features/home/`, `features/shell/`, a `policy/` directory or
`content/model/`.** The only task permitted to touch `app/lib/` is 3.4, and only if 3.3 turns red.

Every task is one commit (GIT-2). Within a task the failing test is written and **seen failing
first**, then the code that passes it — both in that one commit, per PROC-1.

## 1. The pure import graph

- [x] 1.1 Create `app/test/architecture/`. In `pure_boundary_test.dart`, assert that directive
  extraction over a synthetic source string returns the targets of both `import` and `export`, and
  returns nothing when the only mention of `package:flutter/material.dart` sits inside a `//` line
  comment or a `/* */` block comment. Then write `app/test/architecture/import_graph.dart` to pass
  it — pure, no `dart:io` (design D-1). Covers scenario *A commented-out import is not a violation*.
  **Check:** `cd app && flutter test test/architecture/pure_boundary_test.dart` — red before the
  resolver exists, green after.

- [x] 1.2 Assert that `../tokens/tokens.dart` and `package:akimath_app/design/tokens/tokens.dart`
  canonicalise to the same lib-relative key, and that leaf URIs carry the verdicts of plan §2.2:
  `dart:ui`, `dart:math`, `dart:core` and `package:meta` allowed; `package:flutter/…`, `dart:io`,
  `dart:async` and every other `package:` forbidden. Implement canonicalisation and the leaf
  allowlist in `import_graph.dart` (design D-2, D-3).
  **Check:** `cd app && flutter test test/architecture/` green; a `dart:async` case present and
  carrying the D-3 comment that says why it bans nothing useful.

- [x] 1.3 Write `app/test/architecture/source_tree.dart` — the PURE-2 adapter that walks `app/lib/`,
  strips comments and returns `Map<lib-relative-path, source>`, reporting an absent root as absent
  rather than empty. Assert it against the real tree: the map contains
  `design/brand/spec/aki_spec.dart` and `design/tokens/brand_typography.dart`, and
  `features/*/policy/` comes back absent.
  **Check:** `cd app && flutter test test/architecture/` green.

- [x] 1.4 Assert the transitive closure over `import` ∪ `export`: given the **real** sources of
  `design/tokens/tokens.dart` (three exports, no imports) and `design/tokens/brand_typography.dart`
  plus one synthetic `features/round/policy/answer_draft.dart` that imports the barrel, the resolver
  reports a violation whose message names **both** the barrel and the
  `package:flutter/painting.dart` it re-exports. Assert alongside it that a one-hop walk and an
  import-only walk each report zero on the same input — that assertion is the scenario. Implement
  the closure. Covers *The token barrel is caught transitively* and *The closure follows exports,
  not only imports*.
  **Check:** `cd app && flutter test test/architecture/` green, and the violation message pasted
  into the ledger.

- [x] 1.5 Assert that a synthetic graph where `features/home/home.dart` imports `shell/shell.dart`
  while `features/shell/shell.dart` imports `home/home.dart` is reported as a cycle, with the cycle
  printed. Implement cycle detection over the same closure. **The two barrels exist only as map
  entries; neither file is written to disk** (design D-1). Covers *Two features import each other's
  barrel*.
  **Check:** `cd app && flutter test test/architecture/` green; `git status --porcelain app/lib`
  empty.

- [x] 1.6 Assert that a synthetic `policy/` source containing `DateTime.now()` or `Random(` is
  reported with its file and its **line number**, and that `Platform.` is too. Implement the textual
  ambient scan and carry design D-4's three limits as its doc comment — including that a `now`
  parameter is the shape §2.2 wants, not a miss. Covers *An ambient clock is caught*.
  **Check:** `cd app && flutter test test/architecture/` green.

## 2. The gate against the real tree

- [x] 2.1 Run the closure over the real roots (`features/*/policy/`, `design/**/spec/`,
  `content/model/`): assert zero violations today, print `<root> → n files` for each root, and
  fail when `n == 0` for a root that exists on disk while reporting an absent root as absent
  (design D-7). Covers *The gate is not vacuously green*.
  **Check:** `cd app && flutter test test/architecture/` green, with the printed line
  `design/**/spec/ → 2 files` recorded verbatim in the ledger — that number is the coverage claim.

## 3. The screen registry and the overflow gate

- [x] 3.1 Write `app/test/design/screen_registry.dart`: one list of entries, each a label, a builder
  and the viewports it must survive, plus a reason string for any viewport it is excused from
  (design D-5, D-6). Point `app/test/design/no_blurred_shadow_test.dart` at it, deleting its
  hand-written `screens` map (lines 13-17) and changing **no assertion** and not its 2400×4000 pump.
  **Check:** `cd app && flutter test test/design/no_blurred_shadow_test.dart` — the same test count
  as before the edit, recorded on both sides.

- [x] 3.2 Write `app/test/design/screen_overflow_test.dart` with a deliberately-overflowing fixture
  screen — ~803 px of content in 838 px — and assert that the harness **detects** the overflow at
  `textScaler` 1.3 and reports the overflowing widget, while the same fixture is clean at 1.0. Then
  implement the harness: pump at 390×844, `devicePixelRatio` 1, at scale 1.0 and 1.3. The fixture
  lives in the test file; `04 Error` is `f2-core-loop` and naming it here would be an ordering cycle
  (design D-1). Covers *A screen that fits at 1.0 and not at 1.3*.
  **Check:** `cd app && flutter test test/design/screen_overflow_test.dart` green, and the fixture
  assertion inverted once to prove it bites.

- [x] 3.3 **Measure first, commit second** — `.claude/hooks/verify-gate.sh` blocks a commit on a red
  suite, so a task whose exit state is "red, recorded" cannot land. Give all three existing screens
  — `splash · cream`, `splash · green`, `character sheet` — the full 390×844 × {1.0, 1.3} set and
  run the gate **before committing anything**, with no exemption granted in advance (design D-6).
  Record, per screen and per viewport, pass or the overflow message. Then commit each registry entry
  at the set the screen actually survives, and give every viewport a screen is excused from a reason
  string that **quotes the overflow message that earned it** — an exemption is data with evidence,
  never silence.
  **Check:** `cd app && flutter test test/design/screen_overflow_test.dart` green at commit time,
  with the full pre-commit run — failures included — pasted into the ledger.

- [x] 3.4 **Only if 3.3 had to excuse `splash`.** §2.6 entitles `character sheet` to its exemption —
  it is a brand inspector, not a product screen. `splash` is entitled to nothing: a screen that
  breaks for a child with large text is the defect this gate was built to catch. Fix
  `app/lib/features/splash/splash_screen.dart`, then restore its full viewport set and delete its
  reason string in the same commit. **This is the only task in the change that may touch `app/lib/`,
  and it needs Ervin's nod before it lands.** If 3.3 was green on both splash variants, this task is
  a no-op and saying so is the correct outcome.
  **Before editing anything, know that `f0-token-scale` re-measures this same file** (its tasks
  6.1–6.3: Aki 222→210, the three gaps to a uniform 26, the face tile's border 4→3), which shrinks
  `splash · cream` by 26 px and `splash · green` by 14 px on the axis this gate measures, and its
  task 6.4 re-runs this gate and reconciles the registry afterwards. So a fix written here is not
  the last word on `splash_screen.dart` — whatever 3.4 does, `f0-token-scale` edits the same widget
  next. Decide with **design.md D-6 in hand**: an exemption that leaves `req-screen-overflow`
  covering zero product screens is not cheaper than a fix that a later change overwrites. Record
  which you chose and why, and state the overflow margin you measured, so 6.4 can tell whether it is
  retiring an exemption or confirming a fix.
  **Check:** `cd app && flutter analyze --fatal-infos && flutter test` green, no reason string left
  on a `splash` entry, and Tier 2 in task 4.3.

## 4. Evidence and close-out

- [x] 4.1 **Tier 1**, stated with counts: `cd app && flutter analyze --fatal-infos`,
  `cd app && flutter test`, `cd packages/server && npm run verify`. The baseline recorded before the
  change is 34 Flutter tests and 3 TypeScript tests, both green (PROC-5); state the new Flutter
  count and that the TypeScript count is untouched.

- [x] 4.2 **Tier 1b — falsification**, because `import_graph.dart` is pure logic and a closure that
  would stay green with the closure disabled is exactly the vacuity this change exists to prevent.
  Per PROC-5: `git stash push -- app/test/architecture/import_graph.dart`, make the closure follow
  `import` only, run `cd app && flutter test`, record the **named** test that went red (it must be
  1.4's), restore, then prove it with `git diff --quiet -- app/test/architecture/import_graph.dart`
  **and** a `flutter test` back to the count from 4.1. Paste both.

- [x] 4.3 **Tier 2** — applicable only if 3.4 edited `splash_screen.dart`: run the app on a
  simulator with the OS text size raised and look at the splash. If 3.4 was a no-op, the correct
  outcome is to say Tier 2 does not apply: nothing in this change surfaces on screen.

- [x] 4.4 PROC-6 / PROC-7 pass, at archive time and only if there is a lesson: if this change taught
  the project a rule — the shape of an exemption, the barrel trap, anything that bit — write it into
  `.claude/conventions/craftsmanship.md` with an ID, and mirror into `openspec/config.yaml` anything
  that has to reach planning. Both in the same commit, or neither.
