# Design — the round loop

## D1 · The screen holds two fields and no rules

`_RoundScreenState` keeps an index and a draft. It does not know what a legal answer looks like, and
it does not know whether one is right. Both live in `features/round/policy/`, which is a **declared
pure root** — so both are tested by handing them values, with no pumped widget anywhere.

The test of whether the split is real: `answer_draft_test.dart` and `grading_test.dart` between them
carry 16 assertions and not one of them builds a widget.

## D2 · A draft is a value, not a buffer

`AnswerDraft.type()` returns a new draft. A mutable buffer would work and would make the undo,
replay and "what did they type before the verdict" questions each need their own machinery later.

Its refusals are **silent on purpose**: a second decimal separator and a mid-string minus are
dropped with no feedback, because no document specifies feedback for an illegal keypress. Inventing
a shake or a tone here would be inventing a design (DR-K4).

The length ceiling is not fussiness. A child holding a key down would otherwise fill the slot until
it overflows the very viewport `screen_overflow_test.dart` exists to protect.

## D3 · Grading compares canonical forms

`grade` folds U+002D to U+2212 and trims before comparing. The keypad cannot emit a hyphen —
`keypad_layout.dart` sees to that — but a hand-written fixture or a future paste path can, and a
verdict that turned on *which dash was typed* would be the worst kind of wrong: invisible, and the
player is right.

Offline this is the whole of grading, and its verdict is **provisional until sync** per
`ARCHITECTURE.md` §4.

## D4 · The press that dismisses a verdict is consumed

Pressing a key while a result is showing advances the round and does **not** type that character.

A player reaching for the pad after seeing a result should not seed the next answer with whatever
they happened to hit. The first test written for this expected the opposite and was corrected to
match the behaviour rather than the behaviour changed to match the test — recorded because that is
the wrong direction to resolve a mismatch by default, and this is the case where it was right.

## D5 · `demoPack` is a fixture and says so

Five hand-written items so the loop can be played before a pack builder exists. It produces the same
`Item` type `f1b-content-reader` will read out of a bundled JSON pack, so when the reader lands the
*source* changes and the screen does not. Nothing in it computes difficulty — `ladderStep` travels
with the item, because rating never runs in Dart.

## D6 · The debug-underline gate exists because this screen shipped with it

The first run of the round on a device showed a **yellow double underline** under every numeral,
every keypad key and the header. That is Flutter's marker for a `Text` with no `Material` ancestor,
and it looks exactly like a defect.

Nothing in the suite caught it, and nothing *could* have: it is not a colour literal, not a blur,
not an overflow, not a geometry literal. It is a **default nobody chose** — which is precisely the
class of problem a registry-driven walk is good at. So the walk now includes it, and it is asserted
two ways: on styles set directly on a `Text`, and on the style a bare `Text` *inherits*, which is the
one that actually bit.

## Alternatives rejected

- **Grading inside the screen.** It puts an answer rule in a widget, where no pure test reaches it.
- **A mutable answer buffer.** D2.
- **Typing the dismissing press.** D4.
- **Wrapping the screen in `Material` rather than `Scaffold`.** Either fixes the underline;
  `Scaffold` is what every later screen will want anyway, and choosing it now avoids a second
  migration.
