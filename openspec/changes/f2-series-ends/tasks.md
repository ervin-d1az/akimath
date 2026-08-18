# Tasks — a series that ends

Almost everything is on disk: `RoundScreen.onFinished` was built and tested for the teaching item,
the stat readouts exist, the streak exists. This change spends them.

## 1 · The plan

- [x] 1.1 Write `app/test/features/round/policy/series_plan_test.dart`: five from a pack of twenty,
      all distinct; three from a pack of three, not padded; the same plan twice from the same pack.
      **Check:** red.
- [x] 1.2 Write `app/lib/features/round/policy/series_plan.dart`. **PURE** — a list in, a list out,
      no clock and no randomness. The length lives here as a named constant.
      **Check:** green; the pure-boundary gate's `features/*/policy/` count rises by one.

## 2 · The summary

- [x] 2.1 Write `app/test/features/round/ui/series_summary_screen_test.dart`: the three figures, one
      way back, and **no rating and no placeholder for one**.
      **Check:** red. Assert the absence directly — it is a rule the screen could break silently, and
      the verdict screens already carry the same assertion.
- [x] 2.2 Add the scolding sweep across every score from none-of-five to all-of-five.
      **Check:** the same four forbidden words `verdict_screen_test.dart` already sweeps for. A
      summary that says "0 de 5" and nothing else would pass a word check and fail a person — so the
      line varies with the score across four bands, and a control asserts a perfect series and a
      blank one do not say the same thing.
- [x] 2.3 Write `app/lib/features/round/ui/summary/series_summary_screen.dart`.
      **Check:** green. **Two layout defects, both caught by the tests rather than by looking:**
      three natural-width tiles overflowed 390 px by 98 — `4 de 5` is the widest figure on any screen
      in the app — and the first fix, `CrossAxisAlignment.stretch` on the row, inherited an unbounded
      height from the stretching column above it. Each tile now takes a third and scales its figure
      down inside its own box, which is what has to hold at `textScaler` 1.3.
- [x] 2.4 Register it in `test/design/screen_registry.dart`, in the shape the app builds it.
      **Check:** it inherits the no-blur, overflow and text-style gates from one registration.

## 3 · The wiring

- [x] 3.1 `RoundScreen` counts the verdicts it produced and reports them to `onFinished`.
      **Check:** the existing `onFinished` contract is unchanged for callers that pass none — the
      teaching item and every current test must stay green at their present count.
- [x] 3.2 `HomeRoute` draws a plan, passes an ending, shows the summary and returns home.
      **Check:** `app/test/features/round/ui/series_flow_test.dart` — five items, then the summary,
      then the home, with the streak re-read.
- [x] 3.3 Assert the series does not wrap.
      **Check:** the behaviour before this change was to cycle forever; a test that only counts to
      five would pass for a round that then offered a sixth.

## 4 · Evidence

- [x] 4.1 **Tier 1** — `flutter analyze --fatal-infos` clean, suite green, the total as a number.
- [x] 4.2 **Tier 1b** — falsify: make the plan return the whole pack and confirm the length test
      reddens; drop `onFinished` from `HomeRoute` and confirm the wrap test reddens. Restore and
      verify.
- [x] 4.3 **Tier 2** — the whole loop on the iPhone 17: five items, the summary, back to the home.
      This is the change whose entire point is what a player sees, so a screenshot of the summary is
      the evidence, not a description of it.

## 5 · Closing this change's own open question

- [x] 5.1 **A second series drew the same five items**, which was the first thing anyone would
      notice: the pack holds twenty and a player saw five of them, forever. `seriesPlan` now takes
      `from` — how many items the player has already been served — and continues from there,
      wrapping at the end of the pack rather than running out.
      **Check:** offsets 0/5/10 give distinct series; 18 wraps to `i18, i19, i0, i1, i2`; 20 equals
      0; no item repeats inside one series at any offset for packs of 5, 6 and 20; a negative offset
      is refused rather than reinterpreted, because `-1 % 20` is 19 in Dart and would silently start
      near the end.
- [x] 5.2 **It persists**, in `SeriesCursorStore` on the `shared_preferences` the day log already
      uses. Advancing only in memory would give the same five every time the app opened, which is
      the behaviour this exists to end. Unreadable or negative reads as zero — a corrupt preference
      costs a repeated series, never a launch, and a negative would make `seriesPlan` throw.
- [x] 5.3 **The cursor advances on finishing, not on starting.** A player who closes a series after
      one item has not been served five of them in any sense worth remembering, and a test walks
      exactly that path.
      **Check:** falsified both halves — the plan ignoring its offset reddens 5, the cursor never
      advancing reddens 2. 677 tests green.

**Open question 1 in `design.md` is answered and stays recorded** rather than deleted: the answer is
"it advances through the pack and wraps", and the reasoning is above.
