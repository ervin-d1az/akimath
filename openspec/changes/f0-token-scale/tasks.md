Each task is one commit (GIT-2). Each names the check that proves it. Within a task the failing
test is written and **seen red first**, then the code that turns it green lands in the same commit
(PROC-1). Baseline before any of this: `flutter analyze --fatal-infos` clean, **34 Flutter tests
green** across 5 test files.

## 1. Palette

- [x] 1.1 Add `BrandColors.quiet` (`#EAE6F0`).
      Red first: a test in `app/test/design/tokens/brand_colors_test.dart` asserting
      `BrandColors.quiet == const Color(0xFFEAE6F0)` — it does not compile, which is the red.
      Then the constant, with a doc comment naming its two roles (backspace-key fill, skeleton
      block fill) per D3's reason for `quiet` over `keyQuiet`.
      Check: `cd app && flutter test test/design/tokens/brand_colors_test.dart`.
- [x] 1.2 Add `BrandColors.pinkFigure` (`#FF9EC1`).
      Red first: assert it equals `const Color(0xFFFF9EC1)` **and** `isNot(BrandColors.pinkSoft)`.
      The second assertion is the requirement — the two pinks are 7/6/4 apart and the token exists
      to keep them apart.
      Check: same file.
- [x] 1.3 Add `BrandColors.hairline` (ink at 18% → `Color(0x2E1C1A2E)`).
      Red first: assert `hairline.a` rounds to 46/255, `hairline != BrandColors.rule`, and both
      carry the ink RGB. Numeric on purpose (design.md D2 — `0x2E` is also ink's blue byte).
      Then the constant, with a doc comment stating the split: `rule` at 16% is card dividers,
      `hairline` at 18% is board hairlines.
      Check: same file.
- [x] 1.4 Add `BrandColorRole.focus → BrandColors.pink`.
      Red first: assert `BrandColorRole.focus.color == BrandColors.pink`.
      The three existing invariant tests must stay green **unmodified** — that is the evidence D18
      is right that this role was always permitted. Do not touch them.
      Check: `cd app && flutter test test/design/tokens/brand_colors_test.dart` — 5 existing tests
      plus the new ones, all green.

## 2. Shape scale

- [x] 2.1 Create `app/test/design/tokens/brand_shape_test.dart` and add the eight radii.
      Red first: the file does not exist today and nothing tests `BrandShape`. Assert each of
      `radiusSlot 12`, `radiusChip 14`, `radiusControl 16`, `radiusButton 20`, `radiusCardSmall 22`,
      `radiusPanel 24`, `radiusCardMedium 26`, `radiusSheet 32`.
      Assert also that the four existing radii are unchanged (`radiusPill 18`, `radiusCard 28`,
      `radiusIconTile 20`, `radiusScreen 42`) — nothing is renamed (design.md D12).
      Check: `cd app && flutter test test/design/tokens/brand_shape_test.dart`.
- [x] 2.2 Add `borderWidthThin 2.5` and `borderWidthField 2`.
      Red first: assert both values, and that `borderWidth` is still 3 and `iconBorderWidth` still 7.
      Check: same file.
- [x] 2.3 Add `shadowButton (4, 6)` and `shadowDot (2, 3)`.
      Red first: assert `BrandShape.shadowButton == const Offset(4, 6)` and
      `BrandShape.shadowDot == const Offset(2, 3)`, and that the four existing offsets are unchanged.
      `shadowButton` carries a doc comment saying it is the most common shadow in the app.
      Check: same file.
- [x] 2.4 Verify `brand_shape.dart` still imports only `dart:ui show Offset`.
      No new import may enter this file — it is on the pure side of §2.2's ceiling and `policy/`
      imports it directly.
      Check: read the first line; `cd app && flutter analyze --fatal-infos`.

## 3. Type scale

- [x] 3.1 Create `app/test/design/tokens/brand_typography_test.dart` and parameterise `eyebrow`.
      Red first: `BrandText.eyebrow(size: 10, letterSpacing: 0.06)` returns
      `fontFamily == BrandFonts.text`, `fontWeight == FontWeight.w800`, `fontSize == 10`,
      `letterSpacing == 0.6` — tracking is em, resolved against size (design.md D6).
      Add a second test pinning the default: `eyebrow()` is still 12 px at 1.2 px tracking, so no
      existing call site changes.
      Check: `cd app && flutter test test/design/tokens/brand_typography_test.dart`.
- [x] 3.2 Add `BrandText.numeral(size)`.
      Red first: `BrandText.numeral(29)` returns `fontFamily == BrandFonts.display`,
      `fontWeight == FontWeight.w400`, `fontSize == 29`, `height == 1`.
      `sectionTitle` is **not** renamed and **not** removed (design.md D7).
      Check: same file.
- [x] 3.3 Parameterise `cardTitle({size})`, `body({height})` and `caption({size, height})`.
      Red first: one test per style asserting the varied value, plus one asserting the default is
      byte-identical to today's (`cardTitle` 20, `body` height 1.5, `caption` 13 / 1.5).
      Check: same file, and `cd app && flutter test`. The invariant that matters is not the total —
      tasks 1.1–3.2 have added tests by now — but that **the 34 pre-existing tests are green and
      none of them was edited**: `git diff --stat` over the five original test files must be empty.
      A default that moved would have been paid for by touching one of them.
- [x] 3.4 Rewrite `BrandFonts.display`'s doc comment (§3.2, PROC-6).
      It currently reads *"Wordmark and section headers only"* and forbids the usage every design
      document depends on. It becomes the display face for the wordmark, section headers, keypad
      digits, numerals, board digits, stat values and OTP digits — and still not the
      "RETOS MATEMÁTICOS" descriptor, which is Plus Jakarta.
      Check: `cd app && flutter analyze --fatal-infos`; the comment is read in review.

## 4. The colour-literal gate

- [x] 4.1 Add `app/test/architecture/no_color_literal_test.dart`.
      Red first: write the scan, then insert `const Color(0xFFEAE6F0)` into
      `app/lib/design/widgets/loading_dots.dart` and watch it go red naming that file and line.
      This edits versioned production code, so it is restored under **8.2's mechanism**, not by
      hand — `git checkout -- <file>` then `git diff --quiet -- <file>`.
      Scope: all of `app/lib/` except `app/lib/design/tokens/`. Matches `Color(0x`,
      `Color.fromARGB(`, `Color.fromRGBO(` and `Colors.`, with comments stripped first.
      Carve-out by name: `Colors.transparent` (four uses in `theme.dart:37,42,48,53`, verbatim in
      `CLAUDE.md` and BRD-2b).
      **`Colors.` matches on a word boundary — `(?<![A-Za-z0-9_$])Colors\.` — never as a substring.**
      `Colors.` is a substring of `BrandColors.`, so a naive match is red on day one against 94
      correct lines in 12 files (design.md D8 has the measurement). Assert the boundary before the
      carve-out: over `app/lib/` minus `design/tokens/`, the `Colors.` arm alone must return exactly
      the four `theme.dart` hits and nothing else. That assertion is what proves the pattern rather
      than the exclusion list.
      **It must not match `#RRGGBB` text** — `character_sheet_screen.dart:118–121` prints four brand
      hexes as labels and is correct code (design.md D8).
      The test reports the number of files scanned and fails if a root that exists yielded zero
      (design.md D10).
      Check: `cd app && flutter test test/architecture/no_color_literal_test.dart` — green on the
      tree as it stands, red with the injected literal.

## 5. The geometry-literal gate

- [x] 5.1 Replace `speech_bubble.dart`'s `Offset(4, 6)` with `BrandShape.shadowButton`.
      This one carries no new test of its own: the assertion that the literal is gone belongs to the
      gate in 5.2, and the rendered offset is unchanged, so the existing suite is the check. It
      lands **before** the gate so that 5.2 arrives green because the tree is clean, not because the
      scan was scoped around a known violation.
      Requires 2.3.
      Check: `cd app && flutter test` — 34 tests still green; the diff is one line; and
      `grep -n "Offset(" app/lib/design/widgets/speech_bubble.dart` returns nothing.
- [x] 5.2 Add `app/test/architecture/no_geometry_literal_test.dart`.
      Red first: re-insert `Offset(4, 6)` in `speech_bubble.dart` and watch the new test go red
      naming the file and line, then restore under **8.2's mechanism** with its `git diff --quiet`
      proof — this is versioned production code, not a scratch edit.
      Scope: `app/lib/design/widgets/` and `app/lib/features/`, matching `Offset(` with comments
      stripped. `app/lib/design/brand/` is **out of scope** — 95 literals in `aki_spec.dart` and one
      proportional expression in `app_icon.dart:74` are the artwork layer, not widget surfaces
      (design.md D9). Radii and border widths are not scanned, and the test's doc comment says so.
      Same non-vacuity guard as 4.1.
      Check: `cd app && flutter test test/architecture/no_geometry_literal_test.dart`.

## 6. The splash re-measurement (D19)

- [x] 6.1 `Aki(width: 222)` → `Aki(width: 210)`.
      Red first: a test in `app/test/features/splash_screen_test.dart` reading
      `tester.widget<Aki>(find.byType(Aki)).width` and expecting 210.
      Check: `cd app && flutter test test/features/splash_screen_test.dart`.
- [x] 6.2 The three gaps become a uniform 26.
      Red first: assert the three `SizedBox` heights between Aki, the wordmark, the descriptor and
      the dots are all 26 — they are 28 / 28 / 36 today (`space6 - space1` twice, then
      `space7 - space2`).
      Then one private `_gap` constant with a one-line reason, replacing all three expressions
      (design.md D5 — no new spacing token).
      Check: same file.
- [x] 6.3 The face tile's `width: 4` border becomes `BrandShape.borderWidth`.
      Red first: assert the tile's `BoxDecoration.border` width equals `BrandShape.borderWidth`.
      D19's disjunction is settled toward 3 (design.md D4). The 60 px radius keeps its existing
      doc-comment reason and does not change; the 260 px tile and the 232 px face do not change.
      Check: same file, and `cd app && flutter test test/design/no_blurred_shadow_test.dart` — both
      splash variants are in that gate and must stay green. Note that `f0-invariant-tests` task 3.1
      moves that gate's screen list out of the test file and into
      `app/test/design/screen_registry.dart`; since that change lands first (D11), read the registry,
      not a hand-written `screens` map inside the test.

- [x] 6.4 Re-run the overflow gate over both splash variants and reconcile the registry.
      This change is the only one in the F0 fan that **moves a screen's geometry**, so §4's
      definition of done point 2 — "every new screen is added to the 390×844 overflow test" — binds
      it in the direction the plan does not spell out: a change that re-measures an existing screen
      owes the same gate a re-run. Tasks 6.1–6.3 shrink `splash · cream` by 26 px (Aki 222→210, gaps
      92→78) and `splash · green` by 14 px (gaps only — the 260 px tile and its 4→3 border do not
      change the tile's box).
      Two outcomes, and the second is the one that rots silently if this task does not exist:
      (a) both variants were already green in `f0-invariant-tests` task 3.3 — re-run, still green,
      say so and stop;
      (b) task 3.3 had to **excuse** a splash viewport and left a reason string quoting the overflow
      message — that string is now stale, because this change is what fixes it. Delete the exemption,
      restore the full 390×844 × {1.0, 1.3} set for that variant, and say in the ledger that the
      exemption was retired here rather than in `f0-invariant-tests` task 3.4.
      Check: `cd app && flutter test test/design/screen_overflow_test.dart` green, with an assertion
      in that test — named, so it is the check and not a reviewer's glance — that **no registry entry
      whose label starts `splash` carries a reason string**, and that both splash variants are
      registered at the full 390×844 × {1.0, 1.3} set. `character_sheet`'s exemption is untouched and
      the assertion must not cover it (§2.6 entitles it; D-6 of `f0-invariant-tests` explains why).

## 7. PROC-6 — the prose that goes stale in this change

- [x] 7.1 Narrow the pink invariant in `CLAUDE.md`.
      "pink never carries state" becomes the verdict-scoped wording D18 states, so
      `BrandColorRole.focus` is not a standing violation of the entry-point document.
      Check: the replacement line **enumerates the three roles the test actually excludes** —
      `error`, `success`, `action` — so `grep -n "error" CLAUDE.md` finds the invariant line and it
      reads as the assertion in `brand_colors_test.dart`'s third test, not as a broader claim. A
      reviewer can hold the two side by side and see them say the same thing.
- [x] 7.2 Correct `.claude/conventions/craftsmanship.md` in the same commit as 7.1 or immediately
      after — BRD-1 (same pink sentence), BRD-2b (its colour-literal clause is backed by
      `no_color_literal_test.dart` now, not by a manual `grep`) and BRD-2c (its worked example, the
      splash `width: 4`, no longer exists).
      `CLAUDE.md` wins where the two differ, so the rulebook is the file that moves.
      Check, three positive assertions rather than an absence — deleting a sentence must not be able
      to pass this task:
      (a) BRD-1's pink clause is the same sentence as `CLAUDE.md`'s after 7.1;
      (b) BRD-2b names `app/test/architecture/no_color_literal_test.dart` as the test behind it, and
      that test exists and is green;
      (c) BRD-2c still carries a worked example, and the example it now names — the 260 px face
      tile's 60 px radius, justified in its own doc comment — is **on disk**; verify with
      `grep -n "60" app/lib/features/splash/splash_screen.dart`.
- [x] 7.3 Update `CLAUDE.md`'s "Enforced by a test" list with the two new gates and the test count.
      The file states 34 Flutter tests today; it states the new number, and
      `app/test/architecture/` appears in the layout block.
      Check: the numbers in `CLAUDE.md` match `flutter test`'s output in the same session.

## 8. Evidence (PROC-5)

- [x] 8.1 **Tier 1**, stated with counts: `cd app && flutter analyze --fatal-infos` clean, and
      `cd app && flutter test` green with the new total against the 34 baseline.
      `packages/server` is untouched, so its `npm run verify` is reported unchanged (3 tests) rather
      than claimed as coverage of this change.
- [x] 8.2 **Tier 1b — falsification**, on the two gates only. For each: `git stash push -- <file>`,
      inject the literal, `flutter test`, record the **named** test that went red, then
      `git checkout -- <file>` (or `git stash pop`) and prove restoration with
      `git diff --quiet -- <file>` **and** a `flutter test` back to the recorded count. Paste both
      into the ledger.
      No falsification is claimed for the twelve constants — asserting a constant equals itself is
      not falsifiable, and saying so is the honest outcome (design.md, Risks).
- [x] 8.3 **Tier 2**: run the app on a simulator and look at both splash variants. The
      re-measurement is the only visually observable change here, and a widget test proving
      `Aki.width == 210` does not prove the composition still reads.
      **Done 2026-08-16, iPhone 17 simulator, both variants at `flutter run`:**
      - `SplashVariant.cream` — Aki at 210 over the wordmark, the three `_gap` intervals read as
        one uniform rhythm down to the loading dots. Tighter and more even than the 222/28/28/36
        it replaced, not cramped. No overflow.
      - `SplashVariant.brandGreen` — the 260px face tile's outline is now `BrandShape.borderWidth`
        (3) where it was a literal 4. It still holds the face against brand green; at 3px it reads
        as the same weight as every other outlined surface rather than as a thinner special case,
        which is the point of the token. No overflow.
      Method, since `main.dart` had to point at the screen: `main.dart` was backed up outside the
      tree, pointed at each variant in turn, then restored. Restore proven the untracked-safe way
      (PROC-8) — `diff -q` IDENTICAL and `shasum -a 256` back to
      `fe251eb63266fea4d5254e5e37382275a92bddae1101d8606cca80aac5128800`, with `flutter test` back
      at 135 and `git diff -- app/lib/main.dart` empty.
