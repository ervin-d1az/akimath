# The two screens the streak has always implied and never had

## Why

`streakLength` has been pure, tested and correct since F2 — including the
Tijuana daylight-saving defect it was rewritten to fix. It feeds one number on
the home and one on each verdict screen. Nothing has ever read it to decide
that **something is about to be lost**, or that **something just was**.

`AkiMath Perfil y Estados.dc.html` draws both, as `4.12 Racha en riesgo` and
`4.13 Racha perdida`, and they are the only two screens in that document of
fifteen whose every figure the device can already compute. No rating, no
mastery, no per-topic counts, no notification plugin, no audio: a `DayLog`, a
clock and the arithmetic that is already written.

They are also the two the app most visibly lacks. A streak that can only ever
be *reported* is a counter. A streak that says *you have three hours left* and
then, having lost it, says *what you learned did not reset* is the feature.

## What changes

- **`features/home/policy/streak_state.dart` (PURE)** — one closed set for what
  the streak is doing today, and `streakStateFor`, which decides it from the
  recorded days, the moment, and nothing else. It is where "at risk" acquires a
  definition: a live run, nothing recorded today, and the day far enough gone
  that saying so is help rather than nagging.
- **`hoursLeftToday`** beside it — the countdown `4.12` prints, as a `Duration`
  to local midnight. Pure, so the boundary is testable without waiting for one.
- **`features/home/policy/broken_run.dart` (PURE)** — the length of the run that
  ended, read back out of the same `DayLog`. This is what makes `13 → 1`
  sourceable rather than invented.
- **`features/states/ui/streak_at_risk_screen.dart`** and
  **`streak_lost_screen.dart`** — the two screens, composed from the
  `CenteredStateView` that has named them in its own doc comment since F7.
- **`design/widgets/streak_badge.dart`** and **`before_after_counters.dart`** —
  the two pieces `CenteredStateView` has no slot for. Both are `CandySurface`
  compositions, per the design's own §4.3.
- **`design/icons/spec/brand_glyph.dart`** gains `flame`, the one icon `4.12`
  needs and the set does not carry.
- **Reachability**: `FirstRunGate` consults the new policy before the home, and
  `home_route_test.dart` walks to both screens from a seeded `DayLog`. A state
  with no route into it is decoration — `pack.puzzles.first` is the precedent
  this project already paid for.

## Out of scope, named with the reason

The other thirteen screens of that document, and why each waits:

- **`4.4 Notificaciones`, `4.6 Sonido y vibración`** — no notification plugin
  and no audio engine, and any candidate for either must clear CLAUDE.md's
  no-phone-home rule before it is a candidate at all. DR-P2 stands: a switch
  that does nothing is worse than an absent one.
- **`4.14 Habilidad dominada`, `4.15 Tema agotado`** — per-skill mastery and
  per-topic ready counts are F4. `4.14` needs `AkiPose.fan`, which the enum does
  not have, and draws three green-filled elements against its own declared rule
  2. Three reasons, any one sufficient.
- **`4.7 Datos y privacidad`** — `Pedir mi archivo` needs a server job and an
  email path. `Borrar historial` is a **third erasure path** against a schema
  that grants DELETE on `attempts` to `retention_job` alone;
  `one-way-to-erase.test.ts` names the only two files allowed to say
  `inErasureRole`. That is a schema decision, not a screen.
- **`4.3`'s bottom sheet** — the erasure question is already a full screen, and
  CLAUDE.md records why: *the question has to fit a sentence about what
  survives*. A sheet loses that. The typed `BORRAR` gate is worth taking; it is
  its own change.
- **`4.1 Perfil`, `4.2 Ajustes` as a disclosure stack** — both are real and both
  are next. They move the shell (`4.2` is not a nav root; rule 1 names the homes
  as *inicio, mapa, progreso y perfil*), so they are a change about navigation
  and not about states.

## Two readings this change records

**`TE QUEDAN 3 H 46 MIN` does not break "no visible timer."** That invariant is
already scoped in code, not only in prose: `quiet_while_you_solve_test.dart`
holds it over `_solvingSurfaces` — the round, the first item and the five boards
— and the verdict screens have printed elapsed seconds since F2. A countdown on
a screen you reach *instead of* solving is the opposite of a clock watching you
work.

**`4.13`'s `1` is a day number, not a streak, and the two must not be one
value.** The design draws `AYER 13 → HOY 1` on a screen reached *before* the
player has solved anything, where `streakLength` correctly returns **0**. Making
the box read `streakLength` would print a `1` the app's own policy contradicts —
two derivations of one fact disagreeing, which is R2 with a different costume.
So the right box carries `dayOfNewRun`, a separate quantity that is always `1`
by definition: the run that starts today is on its first day, whether or not it
has been earned yet. The headline says the same thing — *LA RACHA VOLVIÓ A UNO*
is a statement about the counter, and *Empezar la de hoy* is the act that makes
it true.
