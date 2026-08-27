# Design

Written for the recommended option. If the human picks Option A, this file is wrong on purpose and
gets replaced.

## D1 — The two keys are two problems, and only one of them has a shape

This is the decision the entry does not make and everything else follows from it.

A decimal answer is a **spelling** problem: `3,5` names a value the contract can already hold
(`7/2`), written differently. `canonicalize` is a speller — `CANONICAL_SHAPE` plus a fold table —
so a new spelling is a new arm of the same kind of rule.

`5²` is not that. It names a value the contract holds (`25`) via an **operation**. Accepting it
means either evaluating inside `packages/contract/src/canon.ts` — the one module both stacks must
agree on character for character, which `ARCHITECTURE.md` §1 lists as a cross-stack contract — or
inventing a `power` shape and then telling a player who typed the right number `25` that they are
wrong. `teclados.md` §8.1 saw this from the design side and called the expression model unbuilt.

So "grow the contract" is not one exit. It is one exit for one key.

## D2 — An empty cell, not a dimmed key

`KeypadKeyView.available` is documented for what it actually means: *"whether this key can do
anything **where it is being shown**"*, invented for the puzzle pad, where a 3×3 board disables the
digits above its ceiling and the same key is live on the next board. It is a per-context statement.

On the item pad these two keys are not context-dependent. No item can enable them, because no
accepted answer can contain what they emit. Drawing them dim says *not now*; the truth is *not
until somebody decides*. Reusing the board's treatment for a permanent absence is what makes this
entry easy to keep leaving open — the pad looks like it is already handling something.

An empty cell claims nothing, and it keeps every other key exactly where the design draws it (D3).

## D3 — The hole lives in the pure layout, as a sealed type

`KeypadLayout.keys` becomes a list of cells, where a cell is either a `KeypadKey` or an empty one.
**A sealed type and not `List<KeypadKey?>`**, which is the argument the file already makes one
level down about `KeyFace`: a nullable field makes every renderer branch on which half is null and
makes unhandled states representable. The precedent is in the same file.

PURE side: `app/lib/design/widgets/spec/keypad_layout.dart` stays pure — no `Canvas`, no widget,
no clock. It gains one type, `KeypadLayout.item` loses two keys, and `knownKeyIds` loses two
members. `_squared` and `_decimal` stay in the file, on the record D4 describes.

Adapter side: `app/lib/design/widgets/keypad.dart` renders an empty cell as an `Expanded` that
draws nothing, so the row still has four tracks and the remaining keys keep the width and the
position `repeat(4,1fr)` gives them. `keypad.dart` holds no new decision — the same PURE-1 split
`KeyRole` → `_fill` already uses.

## D4 — The exclusion set does not empty; it changes what it records

The obvious move is to delete the two keys and empty `keysWithNoGradableAnswer` with them. **That
would destroy the reversal.** The set is half of a two-directional check (archived D3): every
*live* key must be gradable, and every *excluded* key must still be ungradable, so growing
`ANSWER_SHAPES` goes red and tells whoever grew it to put the key back. An empty set can never go
red. Emptying it is how Option B quietly becomes final, which is the one thing this recommendation
must not do.

So the set stays and its meaning shifts by one word. It stops being *keys on the pad that are
disabled* and becomes *keys the design draws that the pad does not offer, and why*. It holds each
one whole — id, face and the text it emits — because the re-check needs the emitted text, and
because the day the contract grows, the key goes back on the pad from this record rather than from
somebody retyping U+00B2 correctly.

The vacuity guard therefore protects the other half. With nothing on the pad excluded, the live
sweep is the one that could iterate nothing, so the gate reports both counts and fails at zero
live — the same shape as `no_color_literal_test.dart` and `touch_target_test.dart`:
`14 live → 14 gradable, 2 refused and still ungradable`.

## D5 — The codepoints travel with the record, not off the edge

`req-keypad-layout-pure`'s second scenario pins three codepoints: U+2212 for negate, U+00B2 for
square, U+002C for decimal. Only the first is on a pad after this change, and the other two do not
disappear — they move into D4's record, beside the reason their keys are off the pad. That keeps
them one transcription rather than none: `teclados.md` §2 verifies these by codepoint and calls
them *"the closest thing to product copy in these two files, and they are easy to get wrong"*.

`knownKeyIds` stays what it says it is — the union of ids **a layout** declares — so it loses two
members, and the gate reads the refused keys from the record instead.

`_minus` stays exactly as it is, U+2212 and never U+002D, still the one place the whole input path
decides that.

## D6 — What this change deliberately cannot verify

`teclados.md` is a digest of `TecladoReactivo`, and the primary source is the `.dc.html` in the
Claude Design project (`CLAUDE.md`, *Where the design lives*). This proposal was written against
the digest. Before the redraw is accepted, whoever owns the design confirms it against the raw
document — `CLAUDE.md` records that treating a digest as the source has already cost real time
twice.
