# Tasks — the icon set

TDD throughout: each test is written and **seen failing** before the code that satisfies it.

## 1 · The dependency allowlist — first, because it constrains everything after it

- [ ] 1.1 Write `app/test/architecture/dependency_allowlist_test.dart`: parse `app/pubspec.yaml` and
      assert `dependencies` is exactly `flutter`, `cupertino_icons`, `meta`.
      **Check:** `flutter test` — the test must be seen **failing first**, so write the assertion
      against a deliberately wrong list, watch it go red, then correct it to the real three and watch
      it go green. A gate that was green from the moment it was written proves nothing (PROC-8).
- [ ] 1.2 Add the second scenario: an added dependency fails the build **and the failure names the
      package**.
      **Check:** add a scratch entry to `pubspec.yaml`, confirm the message names it, then remove the
      entry and confirm the suite returns to its prior count.
- [ ] 1.3 Assert the test reports how many dependencies it scanned and fails at zero.
      **Check:** the count appears in the output — a parser that silently matches nothing is the
      vacuous-gate failure `f0-invariant-tests` already caught once.

## 2 · The pure geometry

- [ ] 2.1 Add `design/icons/spec/` as a declared root in `app/test/architecture/pure_boundary_test.dart`.
      **Check:** the gate reports the root **absent** (0 files), not passing, before task 2.3.
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
