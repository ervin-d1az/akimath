Ordered so a failing test comes before the code that passes it, and so each task is one coherent
commit (GIT-2). Every task names the check that proves it. The test file each group writes to is the
one its scenario names in `specs/offline-pack-format/spec.md`; `design.md` says which side of the
PURE boundary each module lands on (D9). Group 10 is the evidence pass and is not a commit.

Baseline to hold green throughout: 34 Flutter tests, 3 TypeScript tests in `packages/server`, both
analyzers clean. No task in this change touches a file under `app/`.

## 1. The package, red on its first run

- [x] 1.1 Scaffold `packages/contract` as `@akimath/contract`, mirroring `packages/server`:
      `package.json` (private, `type: module`, `engines.node >= 22`, scripts `typecheck`, `test`,
      `verify`, `mutation`, `dry`), `tsconfig.json` with `strict` and `verbatimModuleSyntax`,
      `vitest.config.ts`, a Stryker config whose `mutate` covers `src/` and excludes
      `src/adapters/` (D9), and `zod` pinned to an **exact** version (D8). Install with npm so the
      package carries its own `package-lock.json`.
      Red → green in the same commit: `test/pack_format.test.ts` asserts the package exports a
      frozen `PACK_FORMAT_VERSION` of `1`; see it fail with no module, then add `src/pack.ts`.
      **Check:** `cd packages/contract && npm run verify` — 1 test passing, `tsc --noEmit` clean.

## 2. Canonicalization — the drift site R2 names

- [x] 2.1 Red → green: `test/canon.test.ts` names one test per row of D5's table for the learner
      direction — `""`, `"1/0"`, `"x+1"`, U+0660, ZWSP and a combining mark each rejected with
      their own stable tag, U+2212 folded to ASCII `-` — then `src/canon.ts` with `CHAR_MAP`,
      `canonicalize` and the closed `RejectionTag` union.
      **Check:** `npm test` — each named test red before the module exists, green after.
- [x] 2.2 Red → green: the stored direction. A pack answer is valid only when
      `canonicalize(stored) == stored`; anything `CHAR_MAP` would have folded is rejected
      `not_canonical` (D5). Extend `test/canon.test.ts` with the U+2212-in-a-fixture row, then add
      the validator to `src/canon.ts`.
      **Check:** `npm test` — the new row red first; satisfies `req-pack-fixtures` · *A rejection
      row is rejected*.

## 3. The pack root, the item, and the keypad

- [x] 3.1 Red → green: `test/pack_format.test.ts` parses a minimal pack literal — root
      `pack_format_version`, `pack_salt`, `issued_at`, `expires_at`, `items`; per item `skill_id`,
      `ladder_step`, `keypad`, `stimulus`, `answer`, `diagnosis: null` — and rejects a pack missing
      each required field. Field spelling is snake_case per D7. Then extend `src/pack.ts`.
      **Check:** `npm test`.
- [x] 3.2 Red → green: `test/keypad_layout.test.ts` asserts an item's `keypad` is one of `item`,
      `puzzle`, `otp` and that a per-key list is rejected, then `src/keypad-layout.ts`.
      **Check:** `npm test` — satisfies `req-keypad-layouts`.
- [x] 3.3 Red → green: `AnswerSpec` as a closed union — `(num, den)` for a fraction, an integer for
      the other five families — asserted in `test/pack_format.test.ts`, then `src/answer.ts`. Every
      answer value in a fixture goes through §2's stored-direction validator.
      **Check:** `npm test`.

## 4. Stimulus payloads — six kinds behind one envelope

- [x] 4.1 Red → green: the `{ kind, payload }` envelope and the closed six-member `kind` enum
      (`arithmetic`, `numberSeries`, `matrix`, `analogy`, `hiddenOperation`, `figurate`), with a
      seventh kind rejected. `test/fixtures.test.ts`, then `src/stimulus/index.ts`.
      **Check:** `npm test`.
- [x] 4.2 Red → green: `arithmetic` and `numberSeries` payload schemas, each with a golden fixture
      and a rejection row under `contract/fixtures/stimulus/` named for its wire value (D7).
      **Check:** `npm test` — the fixture parses, the rejection row does not.
- [x] 4.3 Red → green: `matrix` and `analogy`, same discipline.
      **Check:** `npm test`.
- [x] 4.4 Red → green: `hiddenOperation` and `figurate`, same discipline.
      **Check:** `npm test`.

## 5. Puzzle payloads — five kinds, boards that must be solvable

- [x] 5.1 Red → green: the puzzle envelope and the closed `PuzzleKind` enum (`kenken`, `kakuro`,
      `killer`, `magicSquare`, `wordSearch`), with a sixth kind rejected. `test/fixtures.test.ts`,
      then `src/puzzle/index.ts`.
      **Check:** `npm test`.
- [x] 5.2 Red → green: the board validators every kind shares — a cage covers exactly its cells, a
      declared sum is reachable with the digits the board allows, blocked cells are inside the
      board — each with its own stable rejection tag.
      **Check:** `npm test` — one named test per malformed board.
- [x] 5.3 Red → green: the uniqueness check. A board whose constraints admit more than one solution
      is rejected with a stable tag. The search is exhaustive but **not** unconditionally
      affordable — D15's 6×6 cap bounds the board, not the search — so it carries an explicit
      `SEARCH_NODE_BUDGET` and reports `search_budget_exhausted` when a board outruns it (D10).
      Test with a deliberately under-constrained board, with its fixed version, and with a board
      that exceeds the budget.
      **Check:** `npm test` — satisfies `req-pack-fixtures` · *A malformed board is rejected*.
      Every board the check accepts or rejects returns in under 310 ms, measured, and one `size: 6`
      board per puzzle kind is asserted so the claim is tested at the ceiling rather than at 3×3.
- [x] 5.4 Red → green: `kenken`, `kakuro` and `killer` payload schemas, each with a golden fixture
      (board, blocked cells, cages, solution, tutorial steps, reference-sheet content) and a
      rejection row.
      **Check:** `npm test`.
- [x] 5.5 Red → green: `magicSquare` and `wordSearch`, same discipline, plus the enumeration test:
      `contract/fixtures/` holds a golden fixture for each of the six stimulus kinds and each of the
      five puzzle kinds, matched to the enums by filename with no transformation (D7).
      **Check:** `npm test` — satisfies `req-pack-fixtures` · *Eleven kinds are fixtured*.

## 6. Diagnosis — Q2's answer, in a reserved slot

- [x] 6.1 Red → green: `test/diagnosis.test.ts` asserts the digest is
      `HMAC-SHA-256(pack_salt, UTF-8 bytes of the canonical answer)` in lowercase hex, untruncated,
      and that two spellings of the same answer digest identically once canonicalized (D4). Then
      `src/digest.ts`.
      **Check:** `npm test` — the vector is asserted against a literal recorded in the test.
- [x] 6.2 Red → green: the diagnosis payload — separately versioned, nullable, one entry per
      labelled distractor keyed by digest, each carrying `misconception`, `steps` and `explain`
      (es-MX copy, LANG-1). A pack declaring `diagnosis: null` parses and reports the item as
      carrying no diagnosis. No correct answer appears in plaintext anywhere in the pack.
      **Check:** `npm test` — satisfies `req-diagnosis-slot` scenarios 1 and 4.
- [x] 6.3 Red → green: the per-skill generic fallback. An answer matching no labelled distractor
      resolves to the fallback for that item's skill; a pack carrying an item for a skill with no
      fallback is rejected with a stable tag.
      **Check:** `npm test` — satisfies `req-diagnosis-slot` scenarios 2 and 3.
- [x] 6.4 Add the two diagnosis fixtures under `contract/fixtures/` — one item with a filled
      diagnosis and its distractor digests, one with `diagnosis: null` — and assert both parse.
      **Check:** `npm test`.

## 7. Skill-map node state

- [x] 7.1 Red → green: `test/skill_map_state.test.ts` asserts every node the pack references yields
      the state the pack declared, and that a referenced node with no declared state is rejected
      with a stable tag rather than defaulted. Then `src/skill-map.ts`. Nothing in the package
      computes a state from a count, a ratio or a threshold (§7.0 B).
      **Check:** `npm test` — satisfies `req-pack-declares-node-state`.

## 8. The emitter and the frozen artifacts

- [x] 8.1 Red → green: `src/adapters/emit.ts` — the package's only module that touches the
      filesystem (D9) — writes the emitted pack schema under `contract/`. `test/pack_format.test.ts`
      runs the emit twice into a temporary directory and asserts the two outputs are byte-identical.
      **Check:** `npm test`, and `npm run emit` twice followed by `git diff --exit-code`.
- [x] 8.2 Red → green: the emitter also writes `contract/fixtures/canon.golden.json` **from the
      code** (D5), and a test reads it back and re-derives it.
      **Check:** `npm test`, then `git diff --exit-code` after a re-emit.
- [x] 8.3 Red → green: the emitter writes, next to every fixture, the structure the parser
      normalises it to (D6) — the target `f1b-content-reader`'s `req-pack-parity` compares its Dart
      parser against — and the determinism test covers those records.
      **Check:** `npm test` — satisfies `req-pack-artifact` · *The normalised form of every fixture
      is recorded alongside it*.
- [x] 8.4 Commit `contract/` and prove the gate is real: run the emitter from a clean tree and
      confirm nothing changed.
      **Check:** `npm run emit && git diff --exit-code` exits 0 — satisfies `req-pack-artifact` ·
      *The format is regenerated and unchanged*.

## 9. The gates that keep it frozen

- [x] 9.1 Add the `contract` job to `.github/workflows/ci.yml` (D11): a `contract` entry in the
      `changes` path filter covering `packages/contract/**` and `contract/**`, a job that runs
      `npm ci`, `npm run typecheck`, `npm test`, the emitter and `git diff --exit-code` with
      `working-directory: packages/contract`, and the job added to `gate`'s `needs`. Its comment
      states that the `oasdiff` half of `ARCHITECTURE.md` §8 job 4 arrives with
      `f1-contract-emitter`.
      **Check:** the same command sequence run locally exits 0; the pushed run shows `contract`
      green and `gate` reading it.
- [x] 9.2 Extend `.claude/hooks/verify-gate.sh` to run `npm run typecheck` and `npm test` in
      `packages/contract` as well — today its filter fires on any `packages/` path but it only
      checks `packages/server`, so a contract-only change is gated by nothing (D12). Update the
      baseline block in its header with the new counts.
      **Check:** break one contract test on purpose, attempt a commit, see the hook exit 2 naming
      that test; restore the test, prove `git diff --quiet` on the file, and see the commit proceed.
- [x] 9.3 Reconcile the four documents that name the command set, in this same change as PROC-5 and
      PROC-7 require (D12): `CLAUDE.md`'s Commands block and its "What exists today" list,
      `.claude/conventions/craftsmanship.md` PROC-5's verbatim command block, the header comment in
      `.github/workflows/ci.yml` that lists `contract` under *"Not implemented yet, deliberately"*,
      and `openspec/config.yaml`'s `context:` block, which currently tells every future proposal
      that `packages/contract` does not exist.
      **Check:** `grep -rn "packages/contract" CLAUDE.md .claude openspec/config.yaml
      .github/workflows/ci.yml` shows the four files agreeing, and no file still lists the package
      as absent.

## 10. Evidence — the pass, not a commit

- [x] 10.1 **Tier 1**, with counts: `cd app && flutter analyze --fatal-infos`,
      `cd app && flutter test` (unchanged at 34 — this change touches no Dart),
      `cd packages/server && npm run verify` (3), `cd packages/contract && npm run verify` (the new
      count, stated).
- [x] 10.2 **Tier 1b**, not optional here: the canonicalizer is the pure core R2 names as the drift
      site. `cd packages/contract && npm run mutation` (Stryker, score stated, produced in this
      session) and `cd packages/contract && npm run dry` (jscpd). Report the real numbers, never a
      score from another run (PROC-5).
- [x] 10.3 **Tier 2** is unreachable for this change and saying so is the correct outcome: there is
      no endpoint, no environment and no screen — the artifact is a file, and the determinism gate
      in 8.4 is the closest thing to exercising the real thing.
