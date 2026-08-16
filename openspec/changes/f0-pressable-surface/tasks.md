# Tasks — press physics

TDD throughout: each test is written and **seen failing** before the widget that satisfies it.

## 1 · The primitive

- [ ] 1.1 Write `app/test/design/widgets/pressable_surface_test.dart` for the two travel scenarios:
      pressed with `shadow: BrandShape.shadowTile` → child offset `Offset(3, 5)` and **no** `BoxShadow`
      in the decoration; released → offset zero, shadow back to `Offset(4, 6)`, `onPressed` fired
      **exactly once**.
      **Check:** `flutter test` — two failures. Assert the fire count, not merely that it fired.
- [ ] 1.2 Add the fourth scenario: opacity, scale and splash factory unchanged between pressed and
      unpressed builds.
      **Check:** red. This is the scenario that catches a ripple creeping back in later.
- [ ] 1.3 Write `app/lib/design/widgets/pressable_surface.dart`. It reads its **own** `shadow.offset`
      to derive the travel — no lookup table, no typed offset (design D2).
      **Check:** `flutter test` green, and `no_geometry_literal_test.dart` still green with a higher
      scanned-file count than before this change.

## 2 · The shadowless case — DR-5

- [ ] 2.1 Write the `req-press-visible` scenario: constructing a `PressableSurface` with
      `shadow: null` and no named press treatment **fails**.
      **Check:** red, and the failure is a construction failure — not a silently inert widget that
      the test then has to inspect.
- [ ] 2.2 Implement the requirement. Do **not** invent a visual treatment for shadowless controls;
      that is DR-5 and belongs to whoever draws it (design D3).
      **Check:** green. A reviewer can confirm no new colour, offset or curve was introduced here.

## 3 · `BrandButton`

- [ ] 3.1 Write `app/test/design/widgets/brand_button_test.dart`: the secondary button
      (`shadow: null`) fires `onPressed` and does not move; `BrandButton.text` renders
      "Dejar la serie" at its drawn ~29 px height with a hit box measuring at least 48×48; and the
      painted height stays at its drawn size while the hit box clears 48.
      **Check:** `flutter test` — three failures. The third is the one that stops a future fix from
      growing the paint.
- [ ] 3.2 Write `app/lib/design/widgets/brand_button.dart` with the primary, secondary and text
      variants.
      **Check:** green; `flutter analyze --fatal-infos` clean.

## 4 · `IconButtonTile`

- [ ] 4.1 Write `app/test/design/widgets/icon_button_tile_test.dart`: built toggled and untoggled,
      the fill is `#FFD447` and `BrandColors.surface` respectively, and **geometry, press travel and
      hit box are identical in both**.
      **Check:** red. Both fills come from `BrandColors`, so the test names roles rather than hexes.
- [ ] 4.2 Write `app/lib/design/widgets/icon_button_tile.dart` on top of `PressableSurface` —
      48×48, r16, shadow (3,4). It renders whatever glyph it is handed and holds no path data
      (design D5).
      **Check:** green, and `no_color_literal_test.dart` green with a higher scanned-file count.

## 5 · Evidence

- [ ] 5.1 **Tier 1** — `flutter analyze --fatal-infos` clean, `flutter test` green, the new total
      written here as a number.
      **Check:** the count, recorded when known. The baseline before this change is 135.
- [ ] 5.2 **Tier 1b** — no Dart mutation harness is configured, so falsify (PROC-5, which edits
      versioned code and is not optional): change the travel from the shadow's own offset to a typed
      `Offset(3, 5)` and confirm `no_geometry_literal_test.dart` goes red; restore and confirm the
      suite returns to 5.1's count exactly.
      **Check:** the failing assertion quoted, and the restored count matching.
- [ ] 5.3 **Tier 2** — this change is interactive and visual, so it applies: press a primary button,
      a keypad-style tile and a text action on the iPhone 17 simulator and confirm the travel reads
      as sinking rather than sliding.
      **Check:** a screenshot or a written observation per control, and `main.dart` restored
      afterwards **by checksum** — `git diff` is blind to an untracked harness file (PROC-8).
- [ ] 5.4 Record DR-6's six sub-48 controls as still-red-by-design where the plan can find them, so
      the next reader does not read six failures as six defects.
      **Check:** the list named in this change's directory, not in a scratch file.
