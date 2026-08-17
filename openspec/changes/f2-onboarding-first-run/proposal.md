## Why

A fresh install opens straight onto the home with a streak of zero and no explanation of what the
app is or how an answer is typed. `0.2 Bienvenida` and `0.3 Primer reto` are drawn and exist nowhere.

**Phase: F2.** It is the last F2 screen change.

## What Changes

- **`features/onboarding/`** — `0.2 Bienvenida` and `0.3 Primer reto`, plus the flow that decides
  whether a launch is a first one.
- **`features/onboarding/data/`** — a one-flag store, on the same `shared_preferences` the day log
  already uses.
- **`main.dart`** shows the onboarding on a first launch and the home on every other.

## Capabilities

### New Capabilities
- `onboarding`: what a first launch does before the home.

## Impact

- **New:** a feature folder with a policy, a data adapter and two screens.
- `screen_registry.dart` gains both screens.
- **No new dependency** — `shared_preferences` is already in the allowlist with its audit.

## Non-goals

- **`0.4` and `0.5` — calibration.** F4. **D11 is explicit that onboarding ships twice on purpose:**
  the drawn path is `0.2 → 0.3 → 0.4 → 0.5 ×10 → 0.6 → mapa`, and F2 can keep none of the promise
  `0.4` makes — *"unos rápidos para acomodar tu nivel"*. Two small builds beat one broken promise.
- **`0.6` and the map.** F5.
- **An account.** The first run reaches a solved item with no registration and no network call, which
  is the requirement rather than an omission.
- **Rating the teaching item.** `0.3`'s item is fixed and unrated — it teaches the answer format, it
  does not measure anything.

## What this builds on

`RoundScreen` for `0.3`'s item, `AppShell` for the frame, `BrandButton` and `SpeechBubble` for `0.2`,
and the `shared_preferences` decision already taken for the day log.
