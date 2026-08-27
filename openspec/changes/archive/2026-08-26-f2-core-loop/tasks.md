# Tasks — the round loop

## 1 · The pure policies

- [x] 1.1 `AnswerDraft`, test-first: digits append, backspace stops at empty, the draft is a value,
      a second decimal separator and a mid-string minus are refused, a length ceiling holds, and a
      lone minus cannot be submitted.
      **Done.** Seen failing first (`Undefined name 'AnswerDraft'`). 10 tests, no widget pumped.
- [x] 1.2 `Item` and `PromptToken` as pure data in `content/model/`, plus `demoPack`.
      **Done.** The prompt travels rendered; `ladderStep` travels with the item.
- [x] 1.3 `grade`, test-first: canonical comparison, whitespace tolerated, U+002D folded to U+2212,
      an empty answer is wrong rather than an error.
      **Done.** 6 tests, no widget pumped.

## 2 · The screen

- [x] 2.1 `RoundScreen`, with tests covering right, wrong, backspace, empty-submit and the
      dismissing press.
      **Done.** 8 tests.
- [x] 2.2 Register it in `screen_registry.dart` so it inherits the no-blur, overflow and text-style
      gates from one registration.
      **Done.**
- [x] 2.3 Point `main.dart` at it.
      **Done.** This is a real product change, not a harness: the app has something to play.

## 3 · The gate this change owed

- [x] 3.1 `screen_text_style_test.dart` — no registered screen renders text inheriting Flutter's
      missing-`Material` fallback.
      **Done, and falsified:** reverting the screen to a bare `ColoredBox` produces
      `Expected: (null or TextDecoration.none) / Actual: TextDecoration.underline`.

## 4 · Evidence

- [x] 4.1 **Tier 1** — analyze clean, **314 Flutter tests** green (277 before). Pure boundary now
      `design/**/spec/ → 9 files`, `features/*/policy/ → 2 files`, `content/model/ → 2 files` — the
      last two were reporting **absent** before this change.
- [x] 4.2 **Tier 1b** — the debug-underline gate falsified as above.
- [x] 4.3 **Tier 2 — the app was run and played.** iPhone 17 simulator.
      `evidence/round-debug-underlines.png` is the first run, with the yellow marker under every run
      of text. `evidence/round-playable.png` is after the fix: `3/4 + 2/4 =`, a dashed pink answer
      slot, the 4×4 pad with the `a/b` fraction key and the backspace and submit glyphs, and
      `Dejar la serie`. **Two screenshots, because the difference between them is the finding.**

---

## Second slice — the verdict screens, 2026-08-16

- [x] 5.1 `StreakPolicy`, test-first. Pure: attempts and today in, an integer out.
      **Done.** 11 tests. Three of them are about what a streak *never* does: a wrong answer cannot
      decrement it (the policy is never given a verdict, so it has no way to), yesterday still counts
      because a streak that reset at midnight would tell a child who opens the app before playing
      that they had lost it, and an attempt dated after today is ignored rather than trusted — a
      device clock that jumped forward and back should not mint days.
- [x] 5.2 `VerdictScreen`, one screen with two moods.
      **Done.** 11 tests. The forbidden-word check runs over **both** moods, not only the wrong one —
      a scolding word is no better on a right answer — and is paired with an assertion that the wrong
      screen still renders copy, because a screen that passed by saying nothing would be worse than
      one that scolded.
- [x] 5.3 Two tiles, not three, and no rating anywhere.
      **Done.** Q3 and Q4. A verdict screen in F2 carries **no number sync can later contradict**,
      which is why the test also forbids the *words* — a greyed-out rating placeholder would be
      exactly the thing being avoided.
- [x] 5.4 Aki's band overflows upward rather than clipping.
      **Done.** 182 px of art in a 156 px band is 26 px of deliberate overflow; a fixed-height
      `Column` child clips or throws, so the band is a `Stack` with `clipBehavior: Clip.none`.
- [x] 5.5 Quiet timing: the clock is injected, and no timer is visible on either screen.
      **Done.** `RoundScreen` takes `now`, so elapsed is tested by handing it two instants rather
      than by waiting. Both screens are scanned for a running-clock pattern.
- [x] 5.6 Register both moods in `screen_registry.dart`.
      **Done.** They now inherit the no-blur, overflow and text-style gates from one registration —
      and the overflow gate passing at `textScaler` 1.3 is what confirms 5.4 rather than a comment.
- [x] 5.7 **Tier 1** — analyze clean, **467 Flutter tests** green (431 before).
- [x] 5.8 **Tier 2** — `evidence/verdict-acierto.png` and `evidence/verdict-error.png`, iPhone 17.
      The pair is the point: solid ring with a check against **dashed ring with an alert**, so the
      verdict is readable with the hue stripped (BRD-1). And Aki's `slip` pose shows the tail
      uncurled with **the new curl already growing back in green** — the whole of what a wrong answer
      costs. `main.dart` restored and verified by checksum.

## What this slice does not close

- **The diagnosis card.** `req-diagnosis-copy`'s labelled-distractor scenario needs `diagnosis` data
  in the pack and `FractionGlyph`'s **struck** variant; the shipped pack carries neither. The screen
  renders the non-scolding fallback, which is the same requirement's second scenario.
- **`Ver paso`** — not cut, no destination drawn yet (DR-11).
- **The progress strip** and its greyscale scenario.
- **`DayLogStore`.** `attemptDays` is passed in; persistence is a later change. The policy that
  counts them is already pure and tested.
