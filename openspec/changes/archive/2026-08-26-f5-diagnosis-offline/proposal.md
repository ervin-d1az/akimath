# Say something useful when the answer is wrong

## Why

`04 Error` shows *"Casi. Mira cómo va."*, the time and the streak. That is all it has ever
shown. A player who subtracted in the wrong order and one who mistyped get the same screen, and
neither learns anything from it.

The copy already exists. `packages/core/content/misconceptions.json` holds three diagnoses in
es-MX, the builder attaches them to generated items, and `npm run build:pack` reports *10 carry
distractors*. None of it reaches a player, because the app's `Item` has no diagnosis field at
all — so the work is written, tested and unreachable.

`ARCHITECTURE.md` §9 names this as F1.5's whole point: *"without those the error screen degrades
to 'incorrecto', and offline is 100% of F2."* It has, and it is.

## What changes

- The app's pack gains a **misconceptions map** — the copy once per pack, keyed by the same ids
  the builder uses — and an optional **distractor table per item**, mapping a wrong answer to
  one of those ids.
- A pure policy turns a wrong answer into the copy to show, **canonicalising both sides** so
  `12`, `12,0` and `+12` reach the same diagnosis.
- **A wrong answer nothing anticipated still gets steps**, from the pack's fallback. That is the
  common case — the shipped pack will carry distractors for a handful of items — and it is what
  stops the screen regressing to today's bare "Casi."
- `04 Error` shows the steps.

## Out of scope

`explain` is carried in the map and not shown: it is a paragraph for a parent-facing surface
that does not exist yet. Carrying it costs one line per misconception and saves re-authoring;
showing it would put two versions of the same advice on one screen.

Distractors on all seventy items. The builder attaches them to ten of eighty and the fallback
covers the rest — that is the honest shape, not a shortcut.
