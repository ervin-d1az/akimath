## Why

**Phase F2** (`ARCHITECTURE.md` §9), and it is the last thing between what is on disk and that
section's own definition of done: *"★ **Five items played on a plane, no account, no server.**"*

Today you can play but you cannot finish. `HomeRoute` hands `RoundScreen` all twenty items of the
starter pack with no ending, so `_next` wraps modulo the list and the series cycles forever. There is
no "you did it", no count of how many you got, and no reason to stop other than the close control.
A loop with no end is an exercise, not a game.

Everything it needs already exists and is tested. `RoundScreen.onFinished` was built for the
teaching item and ends a round when its last item is solved; the stat tiles, the streak and both
verdict screens are on disk. This change spends them.

## What Changes

- **A series is five items, and then it ends.** Drawn from the bundled pack, and the choice of which
  five is a pure policy so it is testable without a screen.
- **`2.5 Resumen de serie`** — a summary showing what F2 can actually source: how many of the five
  were right, the time taken, and the streak. Then one action back to the home.
- **No rating and no delta on it.** The design makes `2.5` the one screen where a rating delta is
  real, and Q3/D17 put the rating behind the server, which does not exist. The same reasoning
  already took it off both verdict screens: F2 shows no figure that a later sync could contradict.
- **`HomeRoute` wires the ending** and re-reads the day log when the series returns, exactly as it
  already does today.

**BREAKING**: none. The round's behaviour without `onFinished` is unchanged, so the teaching item
and every existing test keep working.

## Capabilities

### New Capabilities

- `series`: what a series is — its length, how its items are chosen, and what a player is told when
  it ends.

### Modified Capabilities

None. `RoundScreen`'s contract is unchanged; this change is its first real caller.

## Impact

**Created** — `app/lib/features/round/policy/series_plan.dart` (pure: which items, in which order),
`app/lib/features/round/ui/summary/series_summary_screen.dart`, and their tests. Both screens join
`test/design/screen_registry.dart`, so they inherit the shadow, overflow and text-style gates.

**Modified** — `app/lib/features/home/ui/home_route.dart` passes a plan and an ending.

**Untouched** — every TypeScript package. This is Dart only.

## Non-goals

- **A rating, a delta, or a skill meter on the summary.** The design draws three tiles and two
  meters on `2.5`; two of those figures are the server's and the server does not exist. Shipping a
  greyed-out placeholder for a number nobody can compute is exactly what Q3 rejected.
- **Adaptive item choice.** Which five items a player gets is `f4-calibration`'s question. Here the
  plan is deterministic and says so.
- **Puzzles, the skill map, or a second series in a row.** F5, F6, and not yet.
- **Sound or motion on the ending.** F8.
