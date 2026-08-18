# Tasks — press physics

TDD throughout: each test is written and **seen failing** before the widget that satisfies it.

## 1 · The primitive

- [x] 1.1 Write `app/test/design/widgets/pressable_surface_test.dart` for the two travel scenarios:
      pressed with `shadow: BrandShape.shadowTile` → child offset `Offset(3, 5)` and **no** `BoxShadow`
      in the decoration; released → offset zero, shadow back to `Offset(4, 6)`, `onPressed` fired
      **exactly once**.
      **Check:** `flutter test` — two failures. Assert the fire count, not merely that it fired.
- [x] 1.2 Add the fourth scenario: opacity, scale and splash factory unchanged between pressed and
      unpressed builds.
      **Check:** red. This is the scenario that catches a ripple creeping back in later.
- [x] 1.3 Write `app/lib/design/widgets/pressable_surface.dart`. It reads its **own** `shadow.offset`
      to derive the travel — no lookup table, no typed offset (design D2).
      **Check:** `flutter test` green, and `no_geometry_literal_test.dart` still green with a higher
      scanned-file count than before this change.

## 2 · The shadowless case — DR-5

- [x] 2.1 Write the `req-press-visible` scenario: constructing a `PressableSurface` with
      `shadow: null` and no named press treatment **fails**.
      **Check:** red, and the failure is a construction failure — not a silently inert widget that
      the test then has to inspect.
- [x] 2.2 Implement the requirement. Do **not** invent a visual treatment for shadowless controls;
      that is DR-5 and belongs to whoever draws it (design D3).
      **Check:** green. A reviewer can confirm no new colour, offset or curve was introduced here.

## 3 · `BrandButton`

- [x] 3.1 Write `app/test/design/widgets/brand_button_test.dart`: the secondary button
      (`shadow: null`) fires `onPressed` and does not move; `BrandButton.text` renders
      "Dejar la serie" at its drawn ~29 px height with a hit box measuring at least 48×48; and the
      painted height stays at its drawn size while the hit box clears 48.
      **Check:** `flutter test` — three failures. The third is the one that stops a future fix from
      growing the paint.
- [x] 3.2 Write `app/lib/design/widgets/brand_button.dart` with the primary, secondary and text
      variants.
      **Check:** green; `flutter analyze --fatal-infos` clean.

## 4 · `IconButtonTile`

- [x] 4.1 Write `app/test/design/widgets/icon_button_tile_test.dart`: built toggled and untoggled,
      the fill is `#FFD447` and `BrandColors.surface` respectively, and **geometry, press travel and
      hit box are identical in both**.
      **Check:** red. Both fills come from `BrandColors`, so the test names roles rather than hexes.
- [x] 4.2 Write `app/lib/design/widgets/icon_button_tile.dart` on top of `PressableSurface` —
      48×48, r16, shadow (3,4). It renders whatever glyph it is handed and holds no path data
      (design D5).
      **Check:** green, and `no_color_literal_test.dart` green with a higher scanned-file count.

## 5 · Evidence

- [x] 5.1 **Tier 1** — `flutter analyze --fatal-infos` clean, `flutter test` green, the new total
      written here as a number.
      **Check:** the count, recorded when known. The baseline before this change is 135.
- [x] 5.2 **Tier 1b** — no Dart mutation harness is configured, so falsify (PROC-5, which edits
      versioned code and is not optional): change the travel from the shadow's own offset to a typed
      `Offset(3, 5)` and confirm `no_geometry_literal_test.dart` goes red; restore and confirm the
      suite returns to 5.1's count exactly.
      **Check:** the failing assertion quoted, and the restored count matching.
- [ ] 5.3 **Tier 2** — **the resting half is evidenced; the travel is not, and the reason is tooling.**
      · **`evidence/controls-resting.png`, iPhone 17, 2026-08-17.** All four control kinds the change
        owns, at real device density: primary button shadow (4,6), keypad key (3,5), `IconButtonTile`
        (3,4) at 48×48, and the text action with **no shadow at all** — which is `PressEffect.none`
        being a decision rather than an omission (DR-5). Every shadow is hard: no blur, no spread, no
        elevation, judged on the device rather than in a widget test.
      · **The travel — NOT obtained.** Capturing a *pressed* control needs a press, and this session
        cannot produce one: no assistive access for `osascript` (`-1719`), no `simctl tap`, no `idb`.
        A synthetic `PointerDownEvent` drives the pressed state under `flutter test` and did nothing
        in the device build. The first version of the harness drew a `PRESIONADO` column that came out
        **pixel-identical** to `REPOSO` — measured, not eyeballed — so it was rewritten to claim only
        what it shows. A screenshot whose own label is wrong is worse than a missing screenshot.
      · Tier 1 does cover the travel: `pressable_surface_test.dart` and
        `icon_button_tile_test.dart` press with `startGesture` and assert the offset and the vanished
        shadow. What is missing is the device judgement — *does it read as sinking rather than
        sliding* — which is the one thing a widget test cannot answer.
      **What closes it:** a human pressing each control on the simulator, or `integration_test` —
      `docs/decisions/OPEN.md` §7. The harness that produced the resting shot was deleted and
      `main.dart` verified clean with `git diff --quiet` (tracked file — PROC-8's git branch, not its
      checksum branch).
- [x] 5.4 Record DR-6's six sub-48 controls as still-red-by-design where the plan can find them, so
      the next reader does not read six failures as six defects.
      **Check:** the list named in this change's directory, not in a scratch file.

---

## Build log — 2026-08-16

**Tier 1.** `flutter analyze --fatal-infos` clean, **212 Flutter tests** green (194 before this
change). 18 of them are this change's: 9 on the primitive, 5 on `BrandButton`, 4 on
`IconButtonTile`.

**Tier 1b — falsified, not asserted.** Task 5.2's check, run: replacing `shadow.dx` / `shadow.dy`
with a typed `Offset(3, 5)` produced

```
Expected: empty
  Actual: [ 'design/widgets/pressable_surface.dart:148 writes Offset(',
            'design/widgets/pressable_surface.dart:149 writes Offset(' ]
Hard-shadow offsets come from BrandShape (BRD-2c).
```

Restored by checksum to `4c5d39aae1dcf0f84cde3ddae7685bf00cebd492e9a830cc92ae1f4e2a7a44b5`, suite
back to 212. So "the travel is read, never typed" is a red build and not a habit.

**Two things found while building.**

1. **The travel came out half.** Padding only the leading side and centring the result lets the
   centring absorb half the offset — measured `Offset(1.5, 2.5)` against an expected `Offset(3, 5)`.
   The shadow's space is now reserved on **both** sides at all times and the surface moves within
   it, which also stops the shadow overlapping whatever sits next to the control.
2. **`PressableSurface` needed a no-fill and a no-outline mode** for `BrandButton.text`, which the
   task list did not anticipate. `background` is nullable and `outlined` is a flag; a text action
   paints neither.

**Deviation from 4.1, stated rather than absorbed.** The scenario names the toggled fill as
`#FFD447`. The widget reads `BrandColorRole.highlight`, which *is* that hex — naming the role rather
than the hue is what BRD-2b requires, and a literal would have failed `no_color_literal_test`
anyway. The test asserts the role.

**Task 5.3 (Tier 2) not run.** These are primitives with no screen yet; the first real press lands
with `f0-keypad`. Stated rather than skipped (PROC-5).
