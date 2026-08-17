# Tasks — the answer rule on the client

## 1 · Parity with the frozen fixture

- [x] 1.1 Write `canon_test.dart` driven by `contract/fixtures/canon.golden.json` — every vector,
      both modes, read from the file rather than copied.
      **Done.** Seen failing first (`'CanonResult' isn't a type`). **19 vectors × 2 modes**, and the
      count is printed so a fixture that shrank to nothing cannot pass quietly.
- [x] 1.2 Write `content/model/canon.dart`.
      **Done.** All 38 assertions green on the first run against the oracle.
- [x] 1.3 Assert the fixture still declares the three character mappings the implementation relies
      on, so adding one on the TypeScript side surfaces here.
      **Done.**

## 2 · Grading through the contract

- [x] 2.1 Rewrite `grade` to read the answer in learner mode and the expected value in stored mode.
      **Done, and it immediately failed a shipped fixture** — `demo-4` stored `−7` with U+2212,
      which is not storage-canonical. The old `trim()` grading passed it by accident; a player
      typing the right answer would have been told they were wrong, on a device, with no error
      anywhere.
- [x] 2.2 Add the negative cases: an unparseable answer is wrong rather than an error, and a
      non-canonical *expected* answer never grades correct.
      **Done.**
- [x] 2.3 Gate the whole shipped pack, not just the item that was broken.
      **Done** — `demo_pack_test.dart` canonicalises every expected answer in stored mode, plus
      unique ids, non-empty prompts and a positive ladder step.

## 3 · Evidence

- [x] 3.1 **Tier 1** — analyze clean, **363 Flutter tests** green (314 before).
      `content/model/ → 3 files` under the pure root.
- [x] 3.2 **Tier 1b** — the fixture defect in 2.1 *is* the falsification: the new rule was run
      against existing content and found a real defect the old one hid. Stronger than a mutation,
      because nobody planted it.
- [ ] 3.3 **Tier 2** — the corrected item renders and grades on the simulator. Deferred to the next
      device pass; the round already ran green and this changes one fixture value.

## 4 · What this change does not close

- The **asset reader** — a bundled JSON pack, its manifest and its expiry.
- The **HMAC membership verifier**. The frozen pack carries a digest rather than a plaintext answer
  (`ARCHITECTURE.md` §4); the fixture holds plaintext and says so.
