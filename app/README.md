# AmbysMath — app

Flutter client for AmbysMath, a math-challenge app in Mexican Spanish.

The backend lives in a separate repository: [`ambysmath-api`](https://github.com/ervin-d1az/ambysmath-api).

## Layout

```
lib/
  design/
    tokens/            colors, typography, shape — the only place literals live
    brand/
      spec/            the brand as pure data: no Canvas, no widgets
      *.dart           widgets and the painter that renders the spec
    widgets/           shared primitives (CandySurface, LoadingDots)
    theme.dart
  features/
    splash/
    brand_gallery/     a live rendering of the design doc, for comparison
```

The `design/brand/spec/` layer is deliberately free of Flutter widget code. The
brand's geometry is data, so its invariants — six gills, tips anchored to stroke
ends, ink drawn before the colored core, the head painted over the gill roots —
are covered by plain unit tests instead of goldens alone.

## Commands

```sh
flutter pub get
flutter analyze
flutter test
flutter run                       # pick a device
flutter run -d web-server --web-port=8787
```

Quality gates beyond the analyzer:

```sh
dart run dart_code_linter:metrics analyze lib     # complexity and structure
dart run mutation_test                            # mutation coverage
npx jscpd lib --formats-exts dart:dart            # duplication
```

## Brand rules the code enforces

- The wordmark refuses to render below 28px — an assert, not a comment.
- `coral` means error and nothing else; `green` means action and success.
- Every surface goes through `CandySurface`, and a test walks each screen's
  rendered tree to fail on any blurred shadow, gradient, or Material elevation.

## Fonts

Darumadrop One and Plus Jakarta Sans are bundled under `assets/fonts/`, not
fetched at runtime — the app is used by minors and must not depend on a
third-party request to render text. Both are SIL Open Font License; the license
texts sit beside the files.
