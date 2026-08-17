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
- [x] 3.3 **Tier 2** — done. `evidence/pack-playing.png`: the app opens the **bundled 20-item pack**
      on the iPhone 17 and shows its first item, `7 + 6 =` at Nivel 1.

## 4 · The asset reader — added 2026-08-16

- [x] 4.1 `content/model/pack.dart`, test-first: the declared item count and payload, `ladder_step`
      from the pack, expiry against an **injected** `now`, and four malformed-pack refusals.
      **Done.** Seen failing first. Expiry is asserted by handing it two dates and requiring the
      answers to differ — a module reaching for `DateTime.now()` returns the same answer for both.
- [x] 4.2 `content/pack_reader.dart` — the one adapter. It touches an `AssetBundle` and decodes a
      string; every decision about what a pack *is* stays in `Pack.fromJson`.
      **Done.** `req-offline-pack-play` is satisfied **by construction**: an `AssetBundle` serves
      what was compiled in, so there is no network request to make.
- [x] 4.3 `assets/packs/starter.json` — **20 real items**, whole-number arithmetic through unlike
      denominators, ladder steps 1–5.
      **Done.** A test loads it through the *real* bundle and checks every item, so a typo in the
      committed pack is a red build rather than a file nothing reads.
- [x] 4.4 `RoundRoute` — loads the pack, refuses an expired one, shows a message on a broken one.
      **Done.** The IO is here so the screen has none; the expiry *decision* is still the pure
      `isExpiredAt`. No spinner — `4.11` is annotated *esqueletos, sin ruedita* and `LoadingDots` is
      not to be repurposed, which a test asserts.
- [x] 4.5 Delete `demo_pack.dart` and make `RoundScreen.items` required.
      **Done.** Two fixtures for one job is one too many: the pack is the content now, and the
      screen takes items rather than defaulting to a second hard-coded list.

## 5 · What this change still does not close

- The **HMAC membership verifier**. `contract/pack.schema.json` carries a `digest`, not a plaintext
  answer (`ARCHITECTURE.md` §4). `assets/packs/starter.json` is the app's **offline fixture format**
  and says so in `pack.dart`'s own doc comment — plaintext is safe here precisely because nothing
  ships: the pack is authored, bundled and played on one device. Reading the frozen format needs
  HMAC-SHA256, which needs a dependency (`package:crypto`), which needs a DEP-1 decision this change
  does **not** take on its own.
- **The pack builder.** `f1-5-pack-builder` generates packs; these 20 items are hand-written.
