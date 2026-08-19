# Design

## D1 — Seven, and why not more

The rotation offers one board per kind per day, so the count *is* the repeat interval. Seven
buys a week.

It is also the ceiling the existing gate allows: `pack_variety_test` asserts every board is
offered within a fortnight, and a kind carrying fifteen would have one that never came round in
that window. That gate is right and this change stays under it deliberately — growing content to
the limit of what the generators can produce would break a promise the pack already makes.

## D2 — The contract permits sizes this client cannot play

A 4×4 magic square draws from 1 to 16. The keypad has nine keys. `readPuzzle` refuses such a
board, and that is how a generated batch of 4×4s and 5×5s was caught during this change — the
app's own reader, at load, before anything shipped.

The limit is the **client's**, not the contract's: a future surface with a larger pad could play
a 6×6 magic square, and `packages/core` should not inherit a keypad. So the generator keeps
producing them and the *content* step is where the constraint applies, with a test naming it so
the next person meets a sentence rather than a `FormatException` with a stack trace.

Only the magic square is affected. KenKen and Killer draw from 1..size, Kakuro from 1..9
whatever its size, and a sopa de letras has no digits at all.

## D3 — Sizes vary within a format

A week of 4×4 KenKens is one puzzle seven times. The sizes span what each format supports and
the client can enter: KenKen and Killer 3–5, Kakuro 3–6, the sopa de letras 6–8, and the magic
square 3 alone for the reason above.
