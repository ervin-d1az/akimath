## 1. Keep core's promises honest before adding to it

- [x] 1.1 Red → green: a test that walks the transitive imports of `src/index.ts` and fails if any
      of them resolves into `@akimath/contract`. It must report how many modules it walked and fail
      at zero, so a broken walker cannot make the claim vacuous (PROC-10). Seen red first by
      pointing it at a module that does import contract.
- [x] 1.2 Confirm `test/dependency-allowlist.test.ts` still passes with contract as a
      devDependency, and extend its recorded rationale to say why the builder does not promote it.
- [x] 1.3 Confirm `test/determinism.test.ts` covers `src/pack/**` — the new pure modules must be
      inside the AST walk, not beside it. Falsify by adding a `Date.now()` to a pack module and
      seeing it go red.

## 2. The declaration, and seeds

- [x] 2.1 Red → green: the declaration type and its parser — seed base, pack salt, validity window,
      ordered sources. A malformed declaration is refused with a message naming the field.
- [x] 2.2 Red → green: seed derivation, `base + n` over generated items only. Two builds differing
      only in base produce different items (req-builder-deterministic).
- [x] 2.3 Falsify: fix the base internally and confirm the differing-base test goes red.

## 3. Lifting authored items

- [ ] 3.1 Red → green: lift one authored arithmetic item into the frozen envelope — `term operator
      term =` becomes `{left, operator, right}`, the answer becomes a digest, `skill_id` and
      `keypad` are added and nothing else changes (req-builder-preserves-authored-content).
- [ ] 3.2 Red → green: lift an item of each non-arithmetic family, whose stimulus payload passes
      through byte-identical.
- [ ] 3.3 Red → green: lift the whole shipped authored file and assert every item is accepted,
      reporting the count and the family breakdown. Reads `app/assets/packs/starter.json` through
      the declaration's path, so drift between the two formats fails here.
- [ ] 3.4 Red → green: an authored answer that is not storage-canonical fails the build naming the
      item (req-builder-answers-are-digests).

## 4. Assembly

- [x] 4.1 Red → green: assemble a pack from one template source and one authored source, and assert
      the frozen validator accepts it (req-builder-sources).
- [x] 4.2 Red → green: the assembled pack carries all six stimulus families given the shipped
      declaration — the assertion that this change cannot regress what a player sees.
- [x] 4.3 Red → green: `skill_nodes` and `skill_fallbacks` are emitted so every `skill_id` an item
      declares is covered; an item naming an undeclared skill fails the build.
- [x] 4.4 Red → green: the emitted pack contains no plaintext canonical answer anywhere, swept over
      every string, reporting how many items were checked.
- [x] 4.5 Red → green: building twice over an unchanged declaration produces byte-identical output.

## 5. Diagnosis copy

- [x] 5.1 Red → green: the misconception copy file and its parser — keyed by snake_case id, every
      `explain` and step non-empty.
- [x] 5.2 Red → green: a distractor resolves its copy by misconception id, and an unknown id fails
      the build rather than emitting an item with no explanation.
- [x] 5.3 Red → green: a distractor whose digest equals the answer is refused, and two distractors
      sharing a digest are refused (req-diagnosis-distractors-are-distinct).
- [x] 5.4 Red → green: the copy sweep — no "incorrecto", "error", "fallaste", "mal" or "equivocado"
      in any emitted string, reporting how many strings were checked
      (req-diagnosis-copy-never-names-the-failure).
- [x] 5.5 Author the misconception copy in es-MX for the arithmetic distractors the one existing
      template can produce — sign errors and off-by-one on integer subtraction at minimum.
- [x] 5.6 Red → green: an item with no diagnosis still yields a valid pack, and the builder reports
      how many items carry distractors and how many do not (req-diagnosis-optional-per-item).

## 6. The CLI and the artifact

- [ ] 6.1 Red → green: the builder refuses to write a pack the frozen validator rejects, reporting
      the tag and exiting non-zero (req-builder-refuses-invalid).
- [ ] 6.2 Red → green: output is written to a temporary path and moved into place only after
      validation, so a failed build leaves any previous artifact untouched.
- [ ] 6.3 Add `npm run build:pack` and emit the committed artifact.
- [ ] 6.4 Add the emit-and-diff step to the `core` CI job, staged before comparison the way the
      `contract` job already does it (req-builder-artifact-committed).

## 7. Evidence

- [ ] 7.1 Tier 1: `npm run verify` green in all three TypeScript packages with the counts stated,
      and `flutter analyze --fatal-infos` + `flutter test` still green — the app is untouched and
      this is what proves it.
- [ ] 7.2 Tier 1b: `npm run mutation` and `npm run dry` in `packages/core`, with the score stated
      and any survivor either killed or explained.
- [ ] 7.3 Tier 1b: record the falsification matrix for the checks that Stryker cannot reach — the
      import-boundary walk, the determinism walk and the copy sweep — each mutation named, each
      seen red, sources restored byte-identical and verified with `diff` against a snapshot
      (PROC-8).
- [ ] 7.4 Confirm `openspec status` reports every task complete, and that the emitted pack in the
      tree is the one the committed declaration produces.
