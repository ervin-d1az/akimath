# Design — the day log

## D1 · Persistence is blocked on a decision, and the decision is not a session's

Writing to a phone's app directory needs a path Flutter exposes only through a plugin —
`path_provider` or `shared_preferences`. Adding one is a **DEP-1 decision**: the audience includes
children under 13, every dependency is checked for whether it phones home *before* it is proposed,
and `dependency_allowlist_test` fails loudly on any addition **precisely so a human takes that call**
rather than a session slipping it in inside an unrelated change.

So this change shipped the model, the seam and the wiring first and **stopped there until the
decision was taken**. Ervin took it the same day; `PrefsDayLogStore` is the one file that followed,
and nothing else moved. The order is the point: a seam built before the decision is a seam that does
not presume it.

The audit, so the answer is a yes or a no rather than homework: both packages are published by the
Flutter team, both are wrappers over platform storage APIs, and neither makes a network request.
`shared_preferences` is the smaller surface for this job — one string, one key.

## D2 · In memory is not a stub

`InMemoryDayLogStore` is the correct implementation of "remember within a session". It is what the
app uses today, and it makes the streak **true** rather than decorative: a figure that resets on
relaunch is at least honest, which a hard-coded one would not be.

## D3 · Days, not moments — a privacy decision

What time of day a child plays is not needed to count a streak, so it is not stored. The encoding is
one ISO date per day and a test asserts it contains no `:`.

Retention is the same argument. Ninety days is comfortably longer than any streak worth showing and
short enough that the file stays bounded — a log kept forever would be a year of a child's activity
sitting on the device for a figure that only needs the current run. **Stated limit:** a streak cannot
be reported longer than the window.

## D4 · Decoding never throws

Storage is the one input nobody reviews. A corrupt file must cost the streak, never the launch — so
an unreadable entry is skipped and an unreadable file is an empty log.

`DateTime.tryParse` turned out to be lenient in a way that mattered: `2026-13-45` **parses**, rolling
over into February 2027. A log entry that never existed would have silently recorded a day the player
was not there. The decoder now requires the parse to round-trip to the text it came from.

## D5 · The home re-reads rather than assumes

`HomeRoute` awaits the pushed session and then re-reads the store. It would have been shorter to
increment a local counter when the series returns, and it would have been wrong: the store is the
source of truth, and a screen that keeps its own tally is a second answer to the same question.

## Alternatives rejected

- **Adding a storage plugin inside this change.** D1. The allowlist gate exists to prevent exactly
  that, and routing around a gate one wrote is worse than the dependency.
- **Hand-rolling a platform channel for the documents path.** More surface than the package, in two
  more languages, to avoid a dependency that would still be the better answer.
- **JSON for the encoding.** It is a list of dates.
- **Incrementing a counter on return.** D5.
