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

## D3 — Both sides go through the canonicaliser

`content/model/canon.dart` is what decides two answers are the same number, and it is checked
against `contract/fixtures/canon.golden.json` — the gate that stops the Dart and TypeScript
canonicalisers drifting.

The typed answer goes through it because a player types `12,0`. **The distractor's key goes
through it too**, because content is hand-written and holding an author to canonical spelling is
a rule nothing enforces. Canonicalising one side and not the other is the version of this bug
that looks correct in review.

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
