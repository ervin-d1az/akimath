# Tasks — the icon set

TDD throughout: each test is written and **seen failing** before the code that satisfies it.

## 1 · The dependency allowlist — first, because it constrains everything after it

- [x] 1.1 Write `app/test/architecture/dependency_allowlist_test.dart`: parse `app/pubspec.yaml` and
      assert `dependencies` is exactly `flutter`, `cupertino_icons`, `meta`.
      **Check:** `flutter test` — the test must be seen **failing first**, so write the assertion
      against a deliberately wrong list, watch it go red, then correct it to the real three and watch
      it go green. A gate that was green from the moment it was written proves nothing (PROC-8).
- [x] 1.2 Add the second scenario: an added dependency fails the build **and the failure names the
      package**.
      **Check:** add a scratch entry to `pubspec.yaml`, confirm the message names it, then remove the
      entry and confirm the suite returns to its prior count.
- [x] 1.3 Assert the test reports how many dependencies it scanned and fails at zero.
      **Check:** the count appears in the output — a parser that silently matches nothing is the
      vacuous-gate failure `f0-invariant-tests` already caught once.

## 2 · The pure geometry

> **Blocked, and not on work: the digests are not reachable.** Tasks 2.2 to 4.3 all transcribe path
> data **verbatim** from the design digests (D2 forbids redrawing one by eye), and nothing in this
> repository or this machine can open them. Re-checked 2026-08-20.
>
> What exists instead is a **named fork of three marks**: `design/icons/spec/nav_glyph_spec.dart`
> holds the house, the sliders and the rising steps, drawn by hand because the bottom bar needed
> marks and could not have them any other way. It says so in its own doc comment, and
> `test/design/icons/nav_glyph_spec_test.dart` counts them **from the source file** — so the
> exception has a number against it and cannot grow unnoticed. It grew once, on 2026-08-19, when
> `Avance` became a root; the counter was reading its own hand-written list at the time and did not
> notice, which is why it reads the source now.
>
> Every other glyph is still a stand-in character in `BrandIcon`. This change reopens the day the
> digests arrive, and until then it is honestly blocked rather than quietly in progress.

- [x] 2.1 Add `design/icons/spec/` as a declared root in `app/test/architecture/pure_boundary_test.dart`.
      **Satisfied by construction, 2026-08-20.** The root is a **glob** — `design/**/spec/` — not a
      list, so `design/icons/spec/` was covered the moment it existed and nobody had to declare it.
      The gate reports 21 files under that root today and `brand_glyph.dart` and
      `nav_glyph_spec.dart` are two of them, so it is covered rather than absent, which is better
      than the check asked for.
- [ ] 2.2 Write `app/test/design/icons/spec/icon_paths_test.dart` for both spec scenarios: backspace
      resolves to **one** `BrandIconSpec` whether requested at 24 or 23 px; the submit arrow's stroke
      width is 3.2 and the backspace's 2.6.
      **Check:** `flutter test` — two failures. The first asserts spec **identity**, not equal
      rendering, or it will pass for the wrong reason (design D3).
- [ ] 2.3 Write `app/lib/design/icons/spec/icon_paths.dart`, transcribing path data **verbatim** from
      the design digests. Where a digest gives no coordinates, leave the glyph out (design D2).
      **Check:** green; pure-boundary gate now reports the root present with a non-zero count.
- [ ] 2.4 Record which of the ~21 glyphs were transcribed and which are waiting on a digest.
      **Check:** the list lives in this change's directory. "21 icons" with no inventory is not a
      count anyone can verify later.

## 3 · The adapter

- [ ] 3.1 Write a widget test rendering one glyph at two sizes and confirming the painted stroke width
      matches the spec's, not a normalised default.
      **Check:** red.
- [ ] 3.2 Write `app/lib/design/icons/brand_icon.dart`. It takes colour and size from the caller and
      holds no palette (proposal, Non-goals).
      **Check:** green; `no_color_literal_test.dart` green with a **higher** scanned-file count than
      before this change; `flutter analyze --fatal-infos` clean.

## 4 · Evidence

- [ ] 4.1 **Tier 1** — `flutter analyze --fatal-infos` clean, `flutter test` green, the new total
      written here as a number. Baseline before this change is 135.
      **Check:** the count, recorded when known.
- [ ] 4.2 **Tier 1b** — no Dart mutation harness is configured, so falsify (PROC-5, which edits
      versioned code and is not optional): change the submit arrow's stroke from 3.2 to 3.0 and
      confirm `icon_paths_test.dart` goes red; restore and confirm the suite returns to 4.1's count
      exactly.
      **Check:** the failing assertion quoted, and the restored count matching.
- [ ] 4.3 **Tier 2** — applies: render a sheet of every transcribed glyph on the iPhone 17 simulator
      and compare against the digests by eye. Transcription errors are exactly the class of defect a
      numeric test cannot catch (design D1).
      **Check:** a screenshot, and `main.dart` restored afterwards **by checksum** — `git diff` is
      blind to an untracked harness file (PROC-8).

---

## Build log — 2026-08-16 · **partially built, and the reason is external**

**Section 1 (the dependency allowlist) is done. Sections 2 and 3 (the geometry) are blocked.**

`f0-brand-icons` calls for ~21 glyphs transcribed **verbatim** from the design digests, and design
D2 forbids redrawing one by eye — an icon drawn from memory is a fork of the design nobody knows
exists. **The digests are not reachable from this session:** `DesignSync list_projects` returns only
`Boletomóvil Design System`, which is the user's employer's and explicitly off-limits. The AkiMath
design project is not listed.

So no glyph was invented. What shipped instead:

- **`app/test/architecture/dependency_allowlist_test.dart`** — the change's most durable output and
  the half that needed no digests. It freezes the runtime list at `flutter`, `cupertino_icons`,
  `meta`, reports the count it scanned, and fails on **any** addition rather than only a
  data-collecting one — the test cannot judge whether a package phones home, so it summons a human
  who can. The failure path is proven against an in-test manifest carrying a fake
  `some_analytics_sdk`, so the real `pubspec.yaml` never had to be edited to prove the gate bites.
  Dev dependencies are deliberately out of scope: they do not ship, and sweeping them in would fire
  the gate on every tooling bump and get it disabled within a week.
- **`app/lib/design/icons/brand_icon.dart`** — the **seam**, decided with Ervin 2026-08-16. Every
  glyph is named in `BrandGlyph` and renders a visible **stand-in character** today. That is a
  placeholder, not an approximation: nothing claims to be the design. Call sites already say
  `BrandIcon(BrandGlyph.backspace)`, so transcribed path data replaces one map and **no screen
  changes**. Without the seam, `f0-keypad` and `f0-verdict` would reach for `Text('⌫')` directly and
  the swap would touch every call site instead of one file.
- Tests: every named glyph renders something non-blank (a missing icon otherwise reaches a
  screenshot unnoticed), one glyph at two sizes stays one glyph, the colour comes from the caller,
  and the icon does **not** scale with the text scaler — an icon growing inside a fixed 48 px tile
  would overflow it.

**To finish this change:** supply the icon digest and sections 2 and 3 proceed as written —
`BrandIconSpec` as pure path data with per-glyph stroke weights (submit 3.2, backspace 2.6), painted
by an adapter, under the existing `design/**/spec/` pure root.

255 Flutter tests green, analyze clean.
