# The states the app started needing the moment it made a request

## Why

The app now talks to two servers, and had one line of copy for every possible
answer — a `switch` inline on a screen, printing a sentence. No loading, no
retry, no distinction between *we broke* and *your signal went*.

The ingredients were on disk and unused: `banner_visual.dart` knew `error` and
`notice`, `SkeletonBlock` existed, and nothing composed either.

## What changes

- **`features/states/policy/account_state.dart` (PURE)** — one closed set for
  where an account stands, and `isOurFault`, which is what the banner's hue
  encodes.
- **`features/states/ui/account_state_view.dart`** — the seven states drawn,
  including `4.11 Cargando` as skeletons.
- **`design/widgets/centered_state_view.dart`** — the frame `4.8`–`4.10`,
  `4.12`–`4.15` and four onboarding screens share, with `headlineLines` as a
  **list** because the design draws its own line breaks.
- **`test/design/no_spinner_test.dart`** — the plan says *"do not invent a
  spinner anywhere"*; now a red build says it too.
- `MeResult` moves to `api/me_result.dart` so a pure policy can read it.

## Out of scope

**`4.1 Perfil` proper.** Its rating, seven-day delta, accuracy and mean time all
come from `GET /me/standing` and `/me/history`, both **501**. This project
already decided once — Q3, the verdict screens — not to draw a figure nothing
can compute. The same answer applies here.
