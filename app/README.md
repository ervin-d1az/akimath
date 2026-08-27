# AkiMath — app

Flutter client for AkiMath, a math-challenge app in Mexican Spanish.

The backend lives in a separate repository: [`akimath-api`](https://github.com/ervin-d1az/akimath-api).

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
dart run dart_code_linter:metrics analyze lib \
  --set-exit-on-violation-level=warning           # complexity and structure
npx jscpd lib --formats-exts dart:dart            # duplication

# Mutation — do not run this bare. Bare, it infers `flutter test` (the whole
# suite, 37s) and mutates all 216 files in lib/: 4,176 mutants, about 43 hours.
# `mutation_test.xml` scopes it to one directory of pure policy and pins the
# test command to that same directory's tests. It exits non-zero below the
# threshold in that file, so it is a gate rather than a report.
dart run mutation_test -f md -o tmp/mutation mutation_test.xml
```

The mutation run is the deeper pass, not the everyday gate — 1m32s for 39
mutants over `lib/features/round/policy/`, scoring 92.31% with three survivors
that are equivalent mutants. Adding a directory to it is two edits made
together: the sources into `<files>`, that directory's test path into the
`<command>`. Mutating code the listed tests do not exercise scores the scope,
not the tests.

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
