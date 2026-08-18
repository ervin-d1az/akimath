## Why

`packages/contract` froze what a canonical answer is — **in TypeScript**. The client grades offline,
so the same rule has to exist in Dart, and **R2 is precisely the risk that the two drift apart.**

Until this change the round graded with a hand-rolled `trim()` and a hyphen fold. It happened to be
right for the five fixture items and was answerable to nothing.

**Phase: F1b.** This is the first half of `f1b-content-reader`: the model and the rule. The asset
reader follows.

## What Changes

- **`app/lib/content/model/canon.dart`** — the Dart canonicaliser, in both modes the contract
  defines: `learner` (what a player typed, normalised) and `stored` (what a system holds, which must
  already be canonical).
- **`app/test/content/model/canon_test.dart`** — parity against
  `contract/fixtures/canon.golden.json` itself. Nineteen vectors × two modes, read from the frozen
  file rather than copied into the test.
- **`grade` now goes through it**, both sides: the answer in learner mode, the item's expected value
  in stored mode.
- **`app/test/content/model/pack_test.dart`** — every shipped item's expected answer must be
  storage-canonical.

## Capabilities

### New Capabilities
- `offline-content`: the answer rule on the client, answerable to the frozen contract.

## Impact

- **New:** `content/model/canon.dart`; two test files.
- **Modified:** `features/round/policy/grading.dart` — was `trim()` plus a hyphen fold, now the real
  rule. `content/model/demo_pack.dart` — one item's expected answer corrected.
- `content/model/` under the pure root goes from 2 files to 3.
- **No new dependency.**

## Non-goals

- **The asset reader.** Reading a bundled JSON pack, the manifest and expiry is the other half of
  `f1b-content-reader` and follows next. The model it produces already exists.
- **The HMAC membership verifier.** The frozen pack carries a digest, not a plaintext answer
  (`ARCHITECTURE.md` §4). Grading against a digest arrives with the reader; the fixture holds
  plaintext and says so.
- **Reducing fractions.** `2/4` is not `1/2`. Deciding otherwise is a pedagogical call the contract
  does not make.

## What this builds on

- **`contract/fixtures/canon.golden.json`** — frozen by `f0-pack-contract`, and the reason this
  change can be checked at all rather than merely reviewed.
