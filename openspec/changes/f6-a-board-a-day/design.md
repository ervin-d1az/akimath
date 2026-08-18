# Design

## D1 — Rotate by day number, not by a stored cursor

A cursor advanced on each visit would need storage, would drift between the home and the card,
and would give a player a different board every time they tapped in and out. A day number needs
none of that: it is a pure function of the date, it is the same all day, and it is the same on
two devices.

`seriesCursor` exists and is a cursor, so the difference is worth naming. A series is *consumed*
— five items you have now seen, which is a fact worth storing. A board is not consumed by being
offered, and this change deliberately does not record whether one was solved (out of scope).

## D2 — The day number is UTC arithmetic over local components

`DateTime.utc(today.year, today.month, today.day).difference(epoch).inDays`.

Local components, so "today" is the player's today. UTC arithmetic, so the subtraction has no
daylight-saving transition in it — a 23-hour local day is still one day, and
`Duration`-based arithmetic over local `DateTime`s is exactly the bug `streak_policy_test`
already guards against under `TZ=America/Tijuana`.

## D3 — Grouping preserves pack order twice over

Kinds appear in the order their first board appears in the pack, and boards within a kind keep
their pack order. Both are content decisions and the pack is where content decisions are made —
the same reason `seriesPlan` takes items in pack order.

That also makes the rotation legible: the third KenKen in the file is the one offered on day 2.

## D4 — `puzzleMenu` is unchanged

`puzzleMenu` names a list of puzzles in order and deliberately names duplicates twice. That
remains correct — it is the *input* that changes, from every board to one board per kind. A
policy that folded duplicates would have hidden this decision inside a naming function.
