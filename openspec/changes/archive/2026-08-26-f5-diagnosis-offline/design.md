# Design

## D1 — Keyed by the answer, not by a digest, and here is when that flips

The frozen format keys distractors by `HMAC(canonical answer)`, and its own comment gives the
reason: *"a readable answer per distractor would make the correct one the one not in the
list."*

That argument does not apply to this format. The app's pack carries `expected` **in plaintext**
— the correct answer is already in the file — so a readable distractor leaks nothing that is
not already there. Keying by digest would buy no secrecy and would cost an HMAC dependency the
app does not have.

**It flips when the app reads the frozen pack** (F4, with sync). At that point the answer stops
travelling in the clear, the D3 argument starts applying, and the lookup keys by digest. Stated
here so that change is a planned consequence rather than a rediscovery.

## D2 — The copy lives once, keyed by misconception id

Seventy items each carrying four lines of es-MX would be most of the pack. The builder already
solved this — `content/misconceptions.json` is a map and items reference ids — so the app's pack
does the same: a `misconceptions` map, and per item a table of `answer → misconception id`.

It also settles what to do with `misconception`: it is the map's key, so it is read by
construction rather than carried unused.

The pack file crossed 50 KB when the generated boards landed, which is the threshold
`pack_reader_test` now guards. A map keeps it there; seventy copies would have doubled it.

## D3 — The typed side is canonicalised; the authored side is validated

This started as "canonicalise both sides", which reads well and is half wrong. Measuring what
the two modes actually do settled it:

- **Learner mode** is the forgiving one. It folds U+2212 to `-`, strips spaces, folds U+2044.
  The keypad emits U+2212 and a content author types the ASCII hyphen, so **without this every
  distractor on a negative answer is dead** — which is the bug worth guarding.
- **Storage mode rewrites essentially nothing.** It refuses `- 9`, `009`, `1⁄2`. It is a
  validator of already-canonical text, not a normaliser.

So canonicalising the authored key is an identity for every key that survives and a refusal for
every key that does not — and the reader already performs that refusal, at load, where it can
name the item. Doing it again in the lookup is the second half of a symmetry that reads well and
does nothing, so the lookup is a plain map read on the canonical typed value.

The falsification run is what forced this: replacing the authored-side canonicalisation with a
raw string comparison changed no test, because there was nothing for it to change.

## D4 — `explain` is carried and not shown

The map holds it because `content/misconceptions.json` already does and copying the map is free;
omitting it means re-authoring when a parent-facing surface arrives. It is not shown because
`steps` and `explain` are two versions of the same advice, and a screen that prints both is
asking a player to read the same thing twice.

## D5 — The registry entry decides the layout, not the screen

`screen_registry.dart` builds `verdict · error` with no diagnosis, so adding steps to the screen
would leave the overflow gate green while the shipped screen overflowed — the same shape as the
home registered with no puzzle cards, and as the hour-long time that overflowed a stat tile.

So a second entry is registered at the maximum the schema admits: four steps, each the longest
line in `misconceptions.json`. Whether the screen then needs to scroll (the home's design D2) or
the copy needs a cap is that entry's answer to give, not a guess made in advance.
