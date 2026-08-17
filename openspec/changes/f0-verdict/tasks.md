# Tasks — the verdict encoding

- [x] 1.1 Write `app/test/design/widgets/spec/verdict_test.dart`: `Verdict`'s surface exposes
      `outline` and `glyph` and **no member returns a `Color`**.
      **Check:** red.
- [x] 1.2 Add the shape scenario: `correct` and `wrong` differ in outline *and* in glyph.
      **Check:** red.
- [x] 1.3 Add the greyscale scenario: the ring adapter's two outputs differ in stroke pattern and
      glyph with colour stripped, and neither is distinguishable by fill alone (design D3).
      **Check:** red. This is the assertion that means something; 1.2 alone passes for any two enum
      values.
- [x] 1.4 Add the mandatory-glyph scenario (design D2).
      **Check:** red.
- [x] 1.5 Write `app/lib/design/widgets/spec/verdict.dart` and `verdict_ring.dart`.
      **Check:** green; analyze clean; both literal gates green with higher counts.

## 2 · Evidence

- [x] 2.1 **Tier 1** — analyze clean, suite green, the total as a number.
- [x] 2.2 **Tier 1b** — falsify (PROC-5): give `wrong` the same outline as `correct` and confirm the
      greyscale test goes red; restore by checksum.
- [ ] 2.3 **Tier 2** — lands with the first screen that shows a verdict.

---

## Build log — 2026-08-16

**Tier 1.** analyze clean, **277 Flutter tests** green (272 before). Pure boundary
`design/**/spec/ → 9 files`.

**Tier 1b — falsified.** Giving `wrong` the same outline as `correct` failed twice:
`Expected: not VerdictOutline.solid / Actual: VerdictOutline.solid`, and the greyscale test with
`Expected: not <false> / Actual: <false>`. The second is the one that matters — it fails on what a
reader sees rather than on two enum values differing. Restored to
`d1c634a6a3558e249a35895cb333afb5639a1a38a97ca9a03800b8bc5b8581fa`.

**The pure-boundary gate caught a real violation, and the fix improved the design.**
`Verdict` needs a glyph *name*, and the name lived in `brand_icon.dart` beside the widget — so the
moment a pure type referenced one, the gate reported:

```
design/widgets/spec/verdict.dart must not reach package:flutter/widgets.dart
   design/widgets/spec/verdict.dart
 → design/icons/brand_icon.dart
 → package:flutter/widgets.dart
```

`BrandGlyph` now lives in `design/icons/spec/brand_glyph.dart`, importing nothing, and `BrandIcon`
renders it and re-exports it so a drawing call site still needs one import. **A name is data;
drawing one is an adapter's job** — the gate found the seam before a reviewer had to.

**Task 2.3 (Tier 2) not run.** It lands with the first screen that shows a verdict.
