## 0. The decision, which is not a task a session can do

- [ ] 0.1 A human picks Option A or Option B, and records the choice in
      `docs/decisions/OPEN.md` #1. **Nothing below starts until this is answered** — every task
      here is written for Option B.
- [ ] 0.2 If Option B: the design owner amends `TecladoReactivo` so the two cells are empty, and
      confirms the amended grid against the raw `.dc.html` rather than against `teclados.md`
      (design D6). Check: the amended document says fourteen keys in a 4×4 grid.

## 1. A grid can hold a hole

- [ ] 1.1 Red → green: the pure layout can express a cell that is not a key, as a sealed type
      rather than a nullable `KeypadKey` (design D3).
      Check: `app/test/design/widgets/spec/keypad_layout_test.dart`.
- [ ] 1.2 Red → green: an empty cell renders as an empty track — the row still has four of them,
      and every remaining key keeps the width and position `repeat(4,1fr)` gives it. Nothing
      pressable is drawn in an empty cell.
      Check: `app/test/design/widgets/keypad_test.dart`.

## 2. The item pad stops offering what the grader refuses

- [ ] 2.1 Red → green: `KeypadLayout.item` is `7 8 9 a/b` / `4 5 6 −x` / `1 2 3 ·` / `· 0 ⌫ ➜` —
      fourteen keys and two empty cells, in the amended design's order.
      Check: `app/test/design/widgets/spec/keypad_layout_test.dart`.
- [ ] 2.2 Red → green: no key on any pad is drawn unavailable for want of a gradable answer, and
      `keysWithNoGradableAnswer` records the two refused keys **whole** — id, face and emitted
      text — as keys the design draws that no pad offers. It does not empty: an empty set can
      never go red when `ANSWER_SHAPES` grows (design D4).
      Check: `app/test/design/widgets/spec/keypad_gradable_test.dart`.
- [ ] 2.3 Red → green: the gate reports both counts and fails at zero live, so the sweep cannot
      pass without checking anything (design D4).
      Check: `keypad_gradable_test.dart` prints
      `14 live → 14 gradable, 2 refused and still ungradable`.
- [ ] 2.4 Red → green: the codepoint contract names U+2212 for negate on the layout and U+00B2 and
      U+002C on the refused record; `knownKeyIds` is the union of ids a layout declares and holds
      neither of the two.
      Check: `app/test/design/widgets/spec/keypad_layout_test.dart`.

## 3. Nothing downstream quietly changed shape

- [ ] 3.1 Red → green: the fill roles still hold — exactly one green key per pad, the operator
      strip is the accent, and the strip's live keys are `a/b` and `−x`.
      Check: `app/test/design/widgets/keypad_roles_test.dart`.
- [ ] 3.2 Green: the round still plays. Every answer in
      `app/assets/packs/starter.json` is typeable on the amended pad — ten of the seventy need
      `a/b`, none needs a key this change removes.
      Check: `app/test/features/round/ui/round_screen_test.dart`, plus a walk of the shipped pack's
      answers against `AnswerDraft.acceptedCharacters`.
- [ ] 3.3 Green: the design gates re-count without being edited to fit. Two fewer pressables per
      item screen changes the sweep totals, and the totals are reported rather than asserted.
      Check: `app/test/design/touch_target_test.dart` and `app/test/design/screen_overflow_test.dart`
      at both viewports, with their new counts stated.
- [ ] 3.4 Green: `AnswerDraft.acceptedCharacters` is unchanged, and its doc comment stops
      describing an unresolved conflict and names the decision instead.
      Check: `app/test/features/round/policy/answer_draft_test.dart`.

## 4. Close the entry

- [ ] 4.1 `docs/decisions/OPEN.md` #1 is struck through and resolved in the same style as #7 —
      what was decided, by whom, and what reverses it.
      Check: the entry names the reversal (`keysWithNoGradableAnswer` going red when
      `ANSWER_SHAPES` grows) rather than saying the keys are gone.

## 5. Evidence

- [ ] 5.1 Tier 1 with numbers: `flutter analyze --fatal-infos` and `flutter test`, the suite count
      stated before and after.
- [ ] 5.2 Tier 1b: falsify both halves of the gate — put a refused key back on the pad and watch
      2.2 go red; teach the canonicaliser to accept `,` in a scratch edit and watch the re-check
      of the refused record go red, which is the reversal Option A depends on.
- [ ] 5.3 Tier 2 on a simulator: the item pad before and after, and the playthrough
      (`flutter test integration_test -d <id>`) driving a five-item series that includes a
      fraction answer.
