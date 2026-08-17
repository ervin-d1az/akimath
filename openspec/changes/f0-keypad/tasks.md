# Tasks — the keypad

TDD throughout: each test is written and **seen failing** before the code that satisfies it.

## 1 · The layouts, as pure data

- [x] 1.1 Write `app/test/design/widgets/spec/keypad_layout_test.dart`: the three layouts are the
      three the design draws — `item` 4×4 calculator order ending `, 0 ⌫ ➜`, `puzzle` 5×2 reading
      order with 1–9 and no `0`/submit, `otp` 3×4 ending `⌫ 0 ↵`.
      **Check:** `flutter test` — red. Assert the **order**, not just the membership: calculator
      versus reading order is the whole of D2.
- [x] 1.2 Add the codepoint scenario: negate is U+2212 and never U+002D, square is U+00B2, decimal
      is U+002C, and no layout declares an id outside the union.
      **Check:** red. Compare code points, not rendered glyphs — U+2212 and U+002D look alike.
- [x] 1.3 Add the face scenario: the `a/b`, `7` and backspace faces are three different types, and
      no face is a `String?` that is null for the icons (design D3).
      **Check:** red.
- [x] 1.4 Write `app/lib/design/widgets/spec/keypad_layout.dart`. No widget import, no `Canvas`.
      **Check:** green; `pure_boundary_test.dart` reports `design/**/spec/` up by one file.

## 2 · The key and the pad

- [x] 2.1 Write `app/test/design/widgets/keypad_test.dart`: item and puzzle keys are the same widget
      at h62/gap 10 and h58/gap 9, both border 3 / r18 / shadow (3,5), both rendering the backspace
      glyph at 24 and 23.
      **Check:** red.
- [x] 2.2 Add the narrow-device scenario: at 320 logical pixels wide every key still measures at
      least 48×48.
      **Check:** red. 320 is the narrowest device worth supporting and the case where a 4-column pad
      is tightest.
- [x] 2.3 Add the two negative scenarios: no `EditableText` and no `TextField` in the tree, and a
      press reports the key id **without** the keypad forming an answer (design D4).
      **Check:** red.
- [x] 2.4 Write `app/lib/design/widgets/keypad.dart` on `PressableSurface`.
      **Check:** green; `flutter analyze --fatal-infos` clean; the colour and geometry gates green
      with higher scanned-file counts.

## 3 · Evidence

- [x] 3.1 **Tier 1** — analyze clean, `flutter test` green, the new total as a number.
- [x] 3.2 **Tier 1b** — falsify (PROC-5): change the negate key's codepoint from U+2212 to U+002D and
      confirm the layout test goes red; restore by checksum and confirm the count returns.
      **Check:** the failing assertion quoted, and the restored count matching.
- [ ] 3.3 **Tier 2** — applies: press the item pad on the iPhone 17 simulator and confirm the keys
      travel and the pad fits. `main.dart` restored by checksum afterwards (PROC-8).

---

## Build log — 2026-08-16

**Tier 1.** analyze clean, **272 Flutter tests** green (255 before). 17 are this change's: 10 on the
layouts, 7 on the widget. Gates: pure boundary `design/**/spec/ → 7 files`, colour `→ 27 files`,
geometry `design/widgets/ → 8 files`.

**Tier 1b — falsified.** Changing the negate key from U+2212 to U+002D produced two failures at once:

```
Expected: <8722>          Expected: not contains '-'
  Actual: <45>              Actual: '-'
```

Two, because the contract is asserted twice on purpose — once on the negate key specifically, and
once as a sweep over **every emitting key in every layout**. The sweep is the one that would catch a
hyphen introduced in the OTP pad by someone who never read this file. Restored to
`99801d3e8443cd7fb39482acf8a0e0d0b19350e6f2132e6c6493d707982d77a0`, suite back to 272.

**The order assertions are sequences, not sets.** `item` starts `7 8 9` and `puzzle` starts `1 2 3`,
and a membership check cannot tell the two apart — which is the entire content of D2. There is also
a standalone test asserting the two *disagree*, so "unify them" fails loudly rather than passing
quietly.

**`knownKeyIds` is a closed union** and every layout is checked against it, so a pad cannot introduce
an id no consumer knows how to handle.

**One thing deferred to its consumer, deliberately.** The keypad reports key presses and assembles
nothing. Two tests hold that line: three digits produce three separate reports, and backspace and
submit report themselves while emitting `null`. Whatever collects those into an answer belongs with
`f2-core-loop`, not here — a keypad that built answers would be a second place that knows the
canonical-answer rule, on the client, which is what `packages/contract` exists to prevent.

**Task 3.3 (Tier 2) not run yet.** It lands with the first screen that mounts a pad.
