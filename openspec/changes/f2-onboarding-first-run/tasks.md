# Tasks — the first run

## 1 · The flag

- [x] 1.1 `OnboardingStore` — one boolean under one key, on the existing `shared_preferences`.
      **Check:** tested against the real `SharedPreferencesAsync` API over the plugin's in-memory
      backend, the way `PrefsDayLogStore` is.
- [x] 1.2 Unreadable storage reports **not completed**, so the welcome screen is shown (design D3).
      **Check:** red first, against a store that reported completed on failure.
- [x] 1.3 It reports its failures rather than swallowing them.
      **Check:** the `f2-day-log` lesson — a tolerant adapter must still be a loud one.

**Found while building 1.2, and it is wider than this file.** A key holding the wrong type throws a
`TypeError`, which is an **`Error` and not an `Exception`** — so `on Exception` misses it and a
launch dies on a corrupt preference. `OnboardingStore` now catches broadly, because the rule is that
nothing about a stored value may prevent a launch and that is wider than the exception hierarchy.
**`PrefsDayLogStore` has the same narrow catch** and is in the current bug hunt's scope, so it is
left for that round rather than edited underneath it.

## 2 · The screens

- [x] 2.1 `0.2 Bienvenida` — Aki, the bubble, one primary action. No account field.
- [ ] 2.2 `0.3 Primer reto` — the fixed teaching item, **Aki absent**, and on submit the flow
      continues to the home.
      **Check:** assert Aki's absence directly; it is a rule the screen could break silently.
- [ ] 2.3 The teaching item records **no day** for the streak (design D4).
      **Check:** a store handed to the flow receives nothing during onboarding.

## 3 · The flow

- [ ] 3.1 `main.dart` chooses onboarding or home from the flag.
- [ ] 3.2 Completing the onboarding sets the flag, and the next launch goes straight to the home.
- [ ] 3.3 Register both screens in `screen_registry.dart`, in the shape the app builds them.
      **Check:** the `f2-home-reduced` lesson — a screen registered bare that the app always wraps
      is a gate checking something nobody ships.

## 4 · Evidence

- [ ] 4.1 **Tier 1** — analyze clean, suite green, the total as a number.
- [ ] 4.2 **Tier 1b** — falsify the once-only rule: make the flag always read false and confirm the
      second-launch test goes red. Restore by checksum.
- [ ] 4.3 **Tier 2** — the two screens on the iPhone 17, and a **second launch going straight to the
      home**, which is the whole point and needs two launches to show.
