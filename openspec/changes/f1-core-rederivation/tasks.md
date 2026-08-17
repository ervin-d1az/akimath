# Tasks — the rederivation machine

**Every numeric in `design.md` is an obligation on a test here, not a fact.** The reference stream's
values, the seed that reproduces the shipped item, and Glickman's constants are all red-until-green.
That is `ARCHITECTURE.md` §3's own lesson: a hand-recalled golden vector enshrines a mistake forever.

## 1 · The package

- [x] 1.1 Scaffold `packages/core` mirroring the two siblings file for file — `package.json`
      (private, `type: module`, `engines.node >= 22`, **no `dependencies` key**), `tsconfig.json`,
      `vitest.config.ts`, `stryker.config.json`, `.jscpd.json`, `.gitignore`, its own
      `package-lock.json`. `@akimath/contract` as a **devDependency** via `file:../contract`, with
      the reason at the declaration (design D1).
      **Check:** `npm run verify` green; `node -e "require('./package.json').dependencies"` is
      `undefined`.
- [x] 1.2 Write `test/dependency-allowlist.test.ts` **before** anything imports anything.
      **Check:** red first. Then green — and it must not be vacuous against an empty set: assert the
      manifest was found and is the right package, and that the devDependencies it declares are
      present, so "no dependencies" is distinguishable from "no file was read" (PROC-11).
- [x] 1.3 Write `test/determinism.test.ts` — a TypeScript AST walk over `src/**` (design D8).
      **Check:** red against a file that calls `Math.random()`. It must report how many files and
      identifiers it walked and fail at zero (PROC-10), refuse the six globals, permit the
      transcendentals **only under `src/rating/`**, and refuse `Number(` on a BigInt in the PRNG
      modules.
      **The control test earned its place immediately.** The first walker skipped any identifier
      whose parent was a property access — which excluded `Date` in `Date.now()`, the single most
      likely violation in the language, since `Date` sits in the *expression* position and
      `Date.now` is not in the banned-property list either. The rule is "unless it is the property
      *name*", so `obj.Date` is ignored and `Date.anything` is not. Nothing but a test that asserts
      the walker sees a violation that is really there would have caught it.
      `Number(` on a BigInt is still to do — carried into task 2.2, where the first BigInt lands.
- [ ] 1.4 Register the package: `tsconfig` references if the siblings use them, the root scripts,
      and `CLAUDE.md`'s command list.
      **Check:** `npm run verify` from a clean `npm ci`.

## 2 · The PRNG — the external anchor first

- [x] 2.1 Write `test/prng/reference.test.ts` from Vigna's published splitmix64 outputs, citing the
      URL and the values in the test.
      **Check:** red — nothing exists. **This test is the only thing in the change that carries
      correctness from outside the repository; write it first or the rest is self-referential.**
      **Vigna publishes the algorithm and no test vector**, which is exactly the situation in which
      a plausible recalled vector gets enshrined. So the anchor was *derived*: his C fetched
      (sha256 `071795a8…`), a seeder and a `main` appended, compiled with clang, run. 40 words across
      5 seeds spanning zero, one, 2⁶³, 2⁶⁴−1 and an arbitrary value. The checksum is part of the
      citation, so "I fetched his file" is checkable rather than asserted.
- [x] 2.2 Write `src/prng/splitmix64.ts`: zero imports, the constants and shifts transcribed with
      the source URL beside them.
      **Check:** 2.1 green.
- [x] 2.3 Write `test/prng/differential.test.ts` — a second, independent implementation in the test
      as an oracle, so a transcription slip has to happen identically twice (design D3).
      **Check:** green, over a spread of seeds including the signed extremes.
- [x] 2.4 Write `test/prng/counter_linearity.test.ts`: the indexed word equals a stateful walk of
      the same length, at seeds `0`, `1`, `2⁶³` and `2⁶⁴−1`.
      **Check:** green. This is what makes statelessness structural rather than a discipline.
- [x] 2.5 Add bounded draws with rejection, and `test/prng/rejection.test.ts`.
      **Check:** the threshold table, plus a span narrow enough to force rejection that still
      terminates and still reaches both ends. Export the limit so its removal is catchable — the
      golden provably cannot catch it.
- [x] 2.6 **Falsify by hand, and record the matrix.** Stryker ships no numeric-literal or bitwise
      mutator, so nothing it does reaches the six constants or the mask. Flip one bit in each
      constant, each shift and the mask in turn; confirm which test goes red for each.
      **Check:** a table in the build log with one row per site. A site no test notices is a hole,
      not a footnote.

      | Site | Result | Caught by |
      |---|---|---|
      | `GOLDEN_GAMMA` low bit | 3 red | `reference` |
      | `MULTIPLIER_1` low bit | 2 red | `reference` |
      | `MULTIPLIER_2` low bit | 2 red | `reference` |
      | `SHIFT_1` 30 → 29 | 2 red | `reference` |
      | `SHIFT_2` 27 → 26 | 2 red | `reference` |
      | `SHIFT_3` 31 → 32 | 2 red | `reference` |
      | `MASK64` one bit short | 3 red | `rejection` |
      | index `+ 1` dropped | 3 red | `reference` |

      Restored byte-identical after each. **And the matrix found a defect rather than only
      confirming coverage:** the `MASK64` case did not redden the suite on the first attempt, it
      **hung** the run, which had to be killed. A rejection loop with a wrong limit never
      terminates, and a hang reports nothing — no failing test, no message. `drawBelow` is now
      bounded and throws, and it takes its word source as a value so the bound is reachable from a
      test; with the real kernel it is unreachable by construction, which is what makes that kind of
      guard rot unverified.

## 3 · Rationals, and the answer boundary

- [ ] 3.1 Write `test/rational.test.ts`: exact arithmetic, lowest terms, sign on the numerator, one
      representation of zero.
      **Check:** red.
- [ ] 3.2 Write `src/rational.ts` — a **method-free frozen interface**. No `toString`, no
      `toNumber`, no parser, no formatter (design D4).
      **Check:** green.
- [ ] 3.3 Write `test/public_surface.test.ts`: set-equality over the public surface, failing on any
      export matching `/render|format|canonical|toString/`.
      **Check:** red against a deliberately added `toString`, then green. Set-equality and not
      `typeof` checks — the contract's own surface test uses `typeof` and a new export ships
      uncovered.

## 4 · One canonical join, in the contract

- [ ] 4.1 Add `renderCanonicalAnswer` to `packages/contract/src/canon.ts`, calling the **private**
      join the canonicaliser already uses (design D5).
      **Check:** a round-trip test — every shape the renderer produces is accepted by the
      canonicaliser as already-canonical.
- [ ] 4.2 Extend `CANON_INPUTS` with `0/5`, `-0/5`, `-3/4`, `4/1`, `12/7` and regenerate
      `contract/fixtures/canon.golden.json`.
      **Check:** `npm run emit` then the tree must not move. **The Dart suite must go green on the
      new vectors without a Dart edit** — its parity test iterates whatever the fixture contains,
      and `-0/5` is the exact hole a defect once shipped through.
- [ ] 4.3 Add the set-equality assertion to `packages/contract/test/public_surface.test.ts`.
      **Check:** red against the new export before 4.1's assertion is added.

## 5 · Rederivation

- [ ] 5.1 Write `src/template.ts`: `TemplateRef` with **four** fields — template, version, seed,
      ladder step (design, Context). Seed is a `bigint`.
      **Check:** the type matches what `issued_items` stores, column for column.
- [ ] 5.2 Write `test/template/registry.test.ts` and `src/registry.ts`: a version resolves to the
      behaviour that version had; a retired version still rederives but is never issued.
      **Check:** red first. Assert both halves — resolvable *and* excluded from issuing.
- [ ] 5.3 Write `test/template/versioning.test.ts`: two versions of one template produce
      **different** items from the same seed, and v1 still reproduces exactly what it always did.
      **Check:** the difference is asserted, not assumed — otherwise the test passes for two
      identical versions and proves nothing.
- [ ] 5.4 Write the reference template, one file per version, and
      `test/template/reference_template.test.ts` reproducing a **named** item from
      `app/assets/packs/starter.json` at a committed seed.
      **Check:** red until the seed is found. Name the item in the test; a test that reproduces
      "some item" is not a test.
- [ ] 5.5 Write `test/template/contract_parity.test.ts`: a generated item, rendered through 4.1, is
      accepted by the frozen item schema.
      **Check:** the validation must reach the **payload**, not stop at the envelope — verify by
      corrupting the payload and confirming the test goes red. A parse that short-circuits at the
      wrapper is a vacuous parity check.

## 6 · The rating

- [ ] 6.1 Write `test/rating/glicko.test.ts` from Glickman's published worked example, cited.
      **Check:** red. External anchor again: the constants are not recalled here either.
- [ ] 6.2 Write `src/rating/glicko.ts`: the session is the rating period, the opponent rating is a
      parameter (design D7), outputs narrowed with `Math.fround` (design D6).
      **Check:** green, and rating a batch together differs from rating one at a time — the whole
      reason the period is the session.
- [ ] 6.3 Write `src/rating/decay.ts` and its test: elapsed **days**, capped, and zero days changes
      nothing.
      **Check:** red first.
- [ ] 6.4 Prove the float32 margin rather than asserting it: perturb the transcendentals' results by
      a plausible cross-engine amount and show the narrowed output does not move.
      **Check:** the test states the margin it measured. This is what makes a byte-exact rating
      fixture honest instead of lucky.

## 7 · The golden artifacts

- [ ] 7.1 Write `src/adapters/emit-golden.ts` — the **only** filesystem writer in the package. It
      calls the three builders and serialises; it holds no decision.
      **Check:** `npm run emit` twice produces no diff.
- [ ] 7.2 Write the three replay tests. Each reads the **committed** artifact from disk and reports
      how many vectors it compared, failing at zero.
      **Check:** a replay that recomputes instead of reading is circular; verify by hand-editing one
      committed value and confirming red.
- [ ] 7.3 Every value that could exceed 2^53 is serialised as a **string**. The same defect just
      cost a migration in `f1-schema-freeze`: `JSON.parse` silently rounds a bigint, and a seed off
      by one rederives an unrelated item.
      **Check:** a round-trip test over the extremes, not over a typical value.

## 8 · Gates

- [ ] 8.1 Add the `core` CI job, and wire it into `gate`'s `needs`.
      **Check:** falsify — change a golden constant, confirm CI goes red. A golden no required check
      reads is decorative.
- [ ] 8.2 Fix **both** sides of the two cross-package edges (design D9): the `core` filter watches
      `packages/contract/**` and `contract/**`; the `dart` filter gains `contract/**`.
      **Check:** `ARCHITECTURE.md` §8 always said the Dart job runs on `dart` ∨ `contract` and the
      workflow only implemented the first half. Verify by touching only `contract/` and confirming
      both jobs run.

## 9 · Documents this change corrects

- [ ] 9.1 `ARCHITECTURE.md` §3: the rederivation key is a quadruple; the package name; the
      determinism gate is an AST walk, not `no-restricted-globals`.
- [ ] 9.2 `CLAUDE.md` and `docs/IMPLEMENTATION-PLAN.md`: the same three, plus the plan's reference to
      a CI job `ts-unit` that does not exist.
      **Check:** CMT-2 — a document stating behaviour the code does not have is a defect fixed with
      the code, in the same commit.

## 10 · Evidence

- [ ] 10.1 **Tier 1** — `npm run verify` green in all three TypeScript packages with the counts
      stated, and `app/` still green at its current count (this change must not move it; if it does,
      4.2 broke the Dart parity test and that is the finding).
- [ ] 10.2 **Tier 1b** — `npm run mutation` and `npm run dry`. **State the score and then state what
      it cannot see**: Stryker reaches no numeric literal and no bitwise operator, so the constants
      and the mask are outside it entirely. Task 2.6's hand matrix is the evidence for those, and the
      score is the evidence for everything else.
- [ ] 10.3 **Tier 2** — does not apply. No endpoint, no screen, nothing observable to a player.
      Stated rather than skipped (PROC-5).
