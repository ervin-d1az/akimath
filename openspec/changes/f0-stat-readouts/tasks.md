# Tasks — the stat readouts

TDD throughout: each test is written and **seen failing** before the widget that satisfies it.

## 1 · The gate, first — it constrains everything after it

- [ ] 1.1 Write `app/test/architecture/no_hue_by_comparison_test.dart`: no colour is chosen by a
      numeric comparison anywhere in `app/lib/`.
      **Check:** seen failing first against a deliberately wrong pattern, then corrected — a gate
      green from the moment it was written proves nothing (PROC-8). It must report the file count it
      scanned and fail at zero.
- [ ] 1.2 State the scan's limits in the source, so they read as limits rather than being found as
      bugs: it cannot see a comparison split across statements, and it must allow a colour resolved
      from an **enum**, which is what `MasteryLevel` legitimately is.
      **Check:** a test for each limit, asserting the stated behaviour rather than leaving it to a
      reader.

## 2 · The meter

- [ ] 2.1 Write `meter_layout_test.dart`: the 6 px ink marker overhangs a h14 track by ±4 and a h16
      track by ±5.
      **Check:** red. Assert both pairs, not a formula (the `f0-dashed-border` lesson — assert the
      measured rows, and assert them through the **named constants** the app uses, not through
      values the test builds itself).
- [ ] 2.2 Write `MeterLayout` and `MasteryLevel` in `design/widgets/spec/`.
      **Check:** green; pure boundary up by two files.
- [ ] 2.3 Write `baseline_meter_test.dart`: the constructor takes a `MasteryLevel` and **no**
      parameter of type `Color`.
      **Check:** red, then green.

## 3 · The tiles, the pill and the chip

- [ ] 3.1 `stat_tile_test.dart` — the three variants' radius, shadow and value size, plus the delta
      rendered as two runs through `EsMxNumber.deltaParts`.
      **Check:** red. The delta assertion must confirm the sign is a separate run, not a substring.
- [ ] 3.2 `stat_pill_test.dart` — both sizes, and the two screens that forced K8: `hero` at height 56
      on yellow, and at height 64 with the default background.
      **Check:** red.
- [ ] 3.3 Write the four widgets on `PressableSurface` where they are pressable.
      **Check:** green; analyze clean; colour and geometry gates green with higher scanned counts.

## 4 · Evidence

- [ ] 4.1 **Tier 1** — analyze clean, suite green, the new total as a number.
- [ ] 4.2 **Tier 1b** — falsify twice, because two different claims are being made: change one meter
      overhang and confirm `meter_layout_test` goes red, and write a `pct >= 90 ? green : pink` into
      a widget and confirm the new gate catches it. Restore both by checksum.
- [ ] 4.3 **Tier 2** — applies: the tiles and a meter on the iPhone 17 at `textScaler` 1.0 and 1.3.
      A readout that fits at 1.0 and clips at 1.3 is the defect this change is most likely to ship,
      and the compositor already produced one of exactly that shape.
