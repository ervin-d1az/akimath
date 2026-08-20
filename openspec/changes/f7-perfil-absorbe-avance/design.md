# Design

## D1 — Why merging beats filling either screen

Three options were on the table: fill `Perfil` from `Avance`, drop the bar to
two roots and leave both thin, or wait for rating to fill both. The third defers
a visible defect behind F4, and the second still leaves a half-empty `Avance`.

The deciding fact is that **no document draws a progress screen**. `Avance` was
invented because the shell needed a second root and the two device figures
needed a home; every line on it is a line `4.1` puts under the identity. Merging
is not a compromise between two designs — it is undoing a split nobody designed.

## D2 — `AppTab.progress` stays in the enum

It would be tidy to delete it. Declared rule 1 names the bar's homes as *inicio,
mapa, progreso y perfil*, so a progress root is something the design asks for and
nobody has drawn — which is a different fact from it not existing, and the enum
is where the difference is recorded. `rootsPresentToday` is the list of what has
a root; that is the one that shrinks.

The same reasoning already ran once in the other direction: `skills` has sat in
the enum without a root since F2, and the bar grew twice without `visibleTabs`
changing.

## D3 — The stat pair is two cards, not two tiles

`4.1` draws a white `RATING` card at `flex 1.3` beside a yellow `RACHA` card at
`flex 1`, both `radius 22` on `shadowButton`, each an eyebrow over a Darumadrop
numeral over a unit line. `Avance` drew two identical compact tiles.

The difference is hierarchy, not decoration: the filled card is the figure the
screen is about. Rating is absent, so the left slot takes `DÍAS` — the honest
figure we have — and the run keeps the fill the design gives it.

`flex 1.3` against `flex 1` goes with it. It is why the left card can hold
`RATING` and a delta line while the right holds a two-digit count.

## D4 — The policy moves, unchanged

`progress_view.dart` holds `HistoryState`, `historyStateFor`, `canRetryHistory`,
`isOurProblem`, `historyMessage`, `historyWorthDrawing` and `entryDate`. All of
it is about a history feed, and the feed is now the profile's. It moves to
`features/profile/policy/history_view.dart` **as a rename**, so the diff shows
no logic changing — and a review that finds some is looking at a mistake.

`features/progress/` is deleted rather than left holding a policy. A feature
directory with no feature in it is a claim about the app that is not true.

## D5 — What replaces Aki on the screen

Nothing. Declared rule 5 lists where she appears and the profile is not among
them; she is in the avatar tile, which is where `4.1` puts her. The encouragement
line goes with her.

This is worth naming because the instinct will be to put it back the next time
the screen looks quiet, and the answer is that it will not be quiet — the
history list is what fills it once a player has synced anything.

## D6 — The route merges too, and keeps both fetches independent

`ProfileRoute` already owned linking, the account state and the erasure. It
takes on `ProgressRoute`'s day-log read and history request unchanged, including
the property that made that route worth reading: **the two halves are fetched
and drawn independently**. The figures come from `shared_preferences` and are
always available; the history needs a session and a network. A route that waited
for both would hide what the device already knows behind a request that may
never answer.

It also keeps `didUpdateWidget`'s re-ask: the session arrives after the player
links, on a screen that is already built.
