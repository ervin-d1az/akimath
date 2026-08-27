# Tasks — the app shell

## 1 · The pure rules

- [x] 1.1 `visibleTabs`, test-first: one root draws nothing, two draw both, order is the
      declaration order.
      **Done.** 6 tests.
- [x] 1.2 `resolveBannerVisual`, test-first: every kind resolves a glyph, the two glyphs differ, and
      the visual carries no `Color`.
      **Done.** 6 tests, including that there is **no** `offline` kind.

## 2 · The frame

- [x] 2.1 `AppShell` — cream, a banner slot, and the staging rule **consumed** rather than merely
      tested (design D1).
      **Done.** The bar builder is injected, so the rule has a real caller today: one root and it is
      not called, two roots and it is called with both tabs in order.
- [x] 2.2 `fullScreenSession` — a route with no navigation affordance.
      **Done.** Tested by pushing from a shell that *is* drawing a bar and asserting the bar is no
      longer visible; asserting it against a shell with no bar would have proved nothing.
- [x] 2.3 `InlineBanner` — one widget, two placements (K7).
      **Check:** `app/test/features/shell/ui/inline_banner_test.dart` — both tones' fills, both
      placements' radii, a glyph for **every** `BannerKind`, and the action chip present only when
      both a label and a callback are given.
      **Landed with no check named and no test file at all**, which a review caught: four decisions
      shipped unasserted, and the policy test's `hasLength(2)` over `BannerPlacement.values` read as
      coverage of arms nothing rendered — the `MathTone.muted` failure again, one file over. That
      pattern is now PROC-11.
- [x] 2.4 `SkeletonBlock` — content-shaped, unanimated.
      **Done.** The no-motion assertion is that no frame is scheduled after a build, which catches a
      shimmer added later.
- [x] 2.5 `main.dart` routes through the shell.
      **Done.**

## 3 · Evidence

- [x] 3.1 **Tier 1** — analyze clean, **489 Flutter tests** green (467 before).
- [x] 3.2 **Tier 1b** — the staging rule's falsification is built into its own tests rather than
      bolted on: the one-root case asserts the builder is **not called**, so an implementation that
      always built a bar fails, and the two-root case asserts the exact tab list, so one that always
      returned empty fails too. Two mutually exclusive failures around one rule.
- [x] 3.3 **Tier 2** — `evidence/shell-no-nav.png`, iPhone 17. The app through the shell, with **no
      bar**, no overflow and no exception in the run log. The screenshot is deliberately
      indistinguishable from the pre-shell one: a frame that changed what a screen looked like would
      be a frame doing something it should not.

## 4 · What this change does not close

- **`AppBottomNav`** — needs a second root, which is F5.
- **The home screen** — `f2-home-reduced`. The round is the single root today, so
  `fullScreenSession` is exercised by its test and has no in-app caller yet; the home is what pushes
  a series.
- **DR-1 to DR-3**, the three offline states nobody drew. The banner exists; its copy in each state
  is a design request.
