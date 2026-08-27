# Evidence

## Tier 1 — the committed suite

| | |
|---|---|
| `packages/core` | **192 tests**, green (98 before this change) |
| `packages/contract` | 227 tests, green — untouched |
| `packages/server` | 24 passed, 25 skipped — untouched; the skipped ones want `TEST_DATABASE_URL` |
| `app` | `flutter analyze --fatal-infos` clean, **805 tests** green — untouched, which is what proves the scope held |

What the gates report when they run:

```
import boundary  · 3 modules reachable from index.ts
determinism      · walked 19 files, ... AST nodes
authored lift    · 70 items → arithmetic 20, analogy 10, figurate 10,
                   hiddenOperation 10, matrix 10, numberSeries 10
pack build       · 5 generated + 70 authored → six families
diagnosis copy   · 3 misconceptions, 10 strings swept
diagnosis cover. · 5/5 generated items carry distractors
```

The emitted artifact:

```
pack: 80 items (10 generated, 70 authored) — analogy 10, arithmetic 30,
      figurate 10, hiddenOperation 10, matrix 10, numberSeries 10
      10 carry distractors, 70 do not
```

## Tier 1b — mutation, duplication, falsification

`npm run dry`: **0 clones**, 18 files, 1728 lines.

`npm run mutation`: **82.03%**, break threshold 70. Recorded honestly: the
package scored ~95% before this change and the new `pack/` modules score 73.6%.
They are validation-heavy, and a large share of the survivors are error-message
string literals — `throw new TypeError("")` still throws, so a test asserting
only that it throws cannot see the difference. The checks that matter are
falsified by hand below.

**The mutation pass found a measurement bug, which is the part worth keeping.**
The first run reported `lift.ts` at 22.68% with 57 mutants having *no coverage*,
while its tests were green. Stryker runs from a sandbox copy of the package, and
the tests reached the authored pack through a counted `../../../../app/...`
path, which lands nowhere in the sandbox — so those tests silently did not run
and covered nothing. `packages/contract/test/fixture-files.ts` had already
learned this and says so in its own header; `test/authored-pack.ts` is its
counterpart, walking up to find the file rather than counting segments. That fix
alone moved the score 72.81 → 80.28 and `lift.ts` 22.68 → 71.13.

### The falsification matrix

Each mutation applied to versioned source, the suite run, the source restored
and verified byte-identical with `diff` against a pre-mutation snapshot
(PROC-8). These cover what Stryker cannot reach — the import walk, the
determinism walk, the copy sweep — and the boundaries it reaches unreliably.

| # | Mutation | Result |
|---|---|---|
| 1 | `index.ts` imports `@akimath/contract` | red — named the file and line |
| 2 | `Date.now()` under `src/pack/` | red — `pack/__probe.ts:1 Date` |
| 3 | seed base ignored, counter never steps | red |
| 4 | int64 seed bound removed | red |
| 5 | pack salt format unchecked | red |
| 6 | validity window ordering unchecked | red |
| 7 | seed base not checked as a number | red |
| 8 | ladder-step ceiling widened to 9999 | red |
| 9 | day-of-month bound removed | **green first** — see below |
| 10 | minus sign left untranslated | red |
| 11 | ASCII hyphen entry emptied | **green first** — see below |
| 12 | expression length unchecked | red |
| 13 | non-canonical answer accepted | red |
| 14 | both prompt and stimulus allowed | red |
| 15 | every answer called an integer | red |
| 16 | digest computed over a constant | **green first** — see below |
| 17 | wrong keypad layout | red |
| 18 | `skill_id` hardcoded to 1 | **green first** — see below |
| 19 | every generated item uses seed index 0 | red |
| 20 | missing skill fallback tolerated | red |
| 21 | `parsePack` validation skipped | **green first** — see below |
| 22 | only the first skill declared | red |
| 23 | generated answer shape hardcoded | **green first** — see below |
| 24 | coinciding distractor kept | red |
| 25 | subtraction rules applied to every operator | red |
| 26 | scolding copy allowed through | red |
| 27 | misconception id format unchecked | red |
| 28 | distractor emitted with no copy | red |
| 29 | empty distractor list emitted | red |
| 30 | `lookup.size === 0` guard removed | **green first** — see below |
| 31 | non-object input guard removed | **green first** — see below |
| 32 | step-count ceiling widened | **green first** — see below |
| 33 | forbidden word emptied | red |
| 34 | misconception id regex `*` → single char | red |

### The nine that were green first

Each was a test that asserted less than it appeared to. All are red now.

1. **Day-of-month (#9)** — the tests fed unparseable text but never an
   impossible date. Seven cases added: a thirteenth month, a thirty-first of
   February, a zeroth day, a twenty-fifth hour, a sixtieth minute, a timestamp
   with no milliseconds, one carrying an offset.
2. **ASCII hyphen (#11)** — only U+2212 was exercised, so the ASCII entry of the
   operator table was dead as far as any test could tell.
3. **Digest over a constant (#16)** — the digest was asserted to match
   `/^[0-9a-f]{64}$/`, which is every property except the one a digest exists
   for. Now compared against `answerDigest` computed independently, with two
   answers required to differ and one answer required to differ across salts.
4. **`skill_id` (#18)** — only ever tested as 1, and the lift is called with 1
   everywhere, so the constant passed.
5. **Validation skipped (#21)** — the test was `expect(...).not.toThrow()`, a
   tautology (PROC-11). It now feeds a series whose hole is off the end of its
   terms and requires `unknown_index_out_of_range`.
6. **Answer shape (#23)** — the one shipped template returns integers, so the
   fraction branch was unreachable. A synthetic template exercises it.
7. **Empty copy file (#30)**, **non-object copy file (#31)**, **step ceiling
   (#32)** — three input-validation branches with no test at all.

## Tier 2

Not applicable in the ordinary sense: this change ships no user-facing surface,
which is the scope decision the proposal records. The nearest equivalent is that
the emitted pack is a real artifact in the tree, parsed by the frozen validator
on its way out and byte-diffed in CI — not a fixture asserting a shape.
