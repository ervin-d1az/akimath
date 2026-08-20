# Design

## D1 — "At risk" needs an hour, and the hour is a product decision

`streakLength` never had to know what time it was. This policy does: *nothing
solved today* is true at 06:00 and means nothing there. The design's own mock
puts the screen at **20:14** and its copy offers *"Recuérdame a las 21:00"*, so
the drawn instance is late evening.

**18:00 local**, named as `atRiskFrom`. Reasoning: the screen has to leave room
for the act it asks for — *"un reto de cuatro minutos"* — and it has to not fire
during a school afternoon when the day is plainly still available. Six hours of
runway is generous for a four-minute ask; three would be a countdown that
arrives with the answer already decided.

It is a constant in the pure module with the reasoning beside it, so moving it is
a one-line diff with a test that fails, and not a number hunted through a widget.

## D2 — The countdown is a `Duration`, and the screen formats it

`hoursLeftToday` returns a `Duration` rather than the string `TE QUEDAN 3 H
46 MIN`. Two reasons. The policy is testable by handing it a moment and reading
a duration, with no es-MX formatting in the assertion; and the formatting is
`EsMxNumber`'s job, which is the one place that already knows this app spells
numbers with a comma decimal and a narrow space.

The chip does **not** tick. A live countdown would need a timer on a screen whose
whole point is to send you somewhere else, and a minute's staleness on a
three-hour figure is not a lie. This is written down because "make it tick" is
the obvious next request and the answer should not be re-derived.

## D3 — `dayOfNewRun` is a separate quantity from `streakLength`

The single sharpest decision in this change, and it is the one an implementer
would get wrong. `4.13` draws `13 → 1` on a screen reached before the player has
solved. `streakLength` returns **0** there, correctly.

If the right-hand box read `streakLength`, the screen would print `0` and the
headline above it would say *VOLVIÓ A UNO*. If it were made to read `1` by
special-casing `streakLength`, two callers of one function would disagree about
what it counts.

So they are two functions. `streakLength` counts days earned. `dayOfNewRun` names
the day the run that starts today is on, which is `1` by definition and carries a
comment saying so. Nothing can drift, because nothing is shared but the log.

## D4 — Where the two screens live in the tree

`features/states/ui/`, beside `account_state_view.dart` — they are states, and
the directory already exists for exactly this. Their policy lives in
`features/home/policy/`, because it reads a `DayLog` and every other consumer of
one is there. That split puts `pure_boundary_test.dart` over the policy for free:
`features/*/policy/` is a glob root, so the file is covered the moment it exists.

## D5 — Reachability is `FirstRunGate`'s, not the home's

The gate already reads one boolean and chooses between the first run and the
home. It becomes: first run, else a streak screen if one is due, else the home.

The alternative — a banner on the home — was rejected. The design draws both as
full screens with Aki at 180 and 196 px and a single forward action, and `4.13`
is annotated *"se pasa la página"*. A page that turns is not a banner. It also
keeps the home free of a fourth conditional band.

**`4.13` is shown once per day**, recorded through the same
`shared_preferences`-backed store shape `OnboardingStore` uses. `4.12` is *not*
once-per-day: the day is still at risk on the second launch, and suppressing the
screen would be the app deciding it had already said enough.

## D6 — Two new widgets, both `CandySurface` compositions

The design digest's §4.3 is explicit that stat cards, badges and tiles are not
new primitives. `StreakBadge` is a yellow pill with a flame, a Darumadrop numeral
and a label. `BeforeAfterCounters` is two boxes and an arrow, where the past one
is **muted, flat and shadowless** and the present one is **yellow, outlined and
raised** — that contrast is the screen's whole argument and it is expressed in
`CandySurface` arguments, not in a painter.

`CenteredStateView` takes them through its existing `content` slot. It needs no
change, which is the test of whether it was the right frame.

## D7 — The flame is the set's first non-navigation glyph

`brand_glyph.dart` holds path data as pure geometry; `BrandIcon` paints it. The
flame's `d` is verbatim from the design (§2.6) and goes in as a spec, painted by
the adapter that already exists. No icon package — `pubspec.yaml` has no icon
source and CLAUDE.md's dependency floor is the reason.

## D8 — Overflow is checked at 1.3 on the first screen, not at the end

`screen_overflow_test.dart` runs every registered screen at `textScaler` 1.0
**and 1.3**. A 46 px Darumadrop headline over a 196 px Aki over a card over two
buttons is the exact shape that fails at 1.3. `CenteredStateView` scrolls inside
an `Expanded`, so the frame is already right — but the Aki widths the design
gives (180, 196) are larger than the frame's own default of 150, and that is the
knob to turn if 1.3 overflows. Register both screens **before** the layout is
finished, so the gate reports the failure while it is still cheap.
