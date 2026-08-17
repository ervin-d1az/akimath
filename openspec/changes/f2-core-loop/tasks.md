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
