---
name: device-walkthrough
description: Walk a flow on the iOS simulator by tapping accessibility labels — reviewing a screen, reproducing a report, or getting through a step no automated test can reach. Use when someone asks to see something on the device, to try a flow by hand, or when a screenshot shows something the tests do not catch.
allowed-tools: Bash
license: MIT
---

Drive the app on a booted simulator, tapping by accessibility label.

## Which tool, and when

**`flutter test integration_test -d <udid>` is the default.** It drives the app
from the inside, taps by widget, and is the only one of the two that catches a
regression next month. Anything worth keeping goes there.

**This skill is for the other half**: looking at a flow, reacting to what is on
screen, reproducing a bug report, or getting past a step that cannot be
automated — a verification code in an inbox being the standing example.

Do not convert integration tests into walkthroughs. The suites in
`app/integration_test/` sat broken for weeks because nothing ran them; the fix
was running them, not replacing them with something manual.

## Setup, once per machine

```sh
brew trust --formula facebook/fb/idb-companion   # Homebrew requires this now
brew install idb-companion                        # a bottle; no Xcode compile
python3 -m venv /tmp/idbenv && /tmp/idbenv/bin/pip install fb-idb
```

`idb-companion` is the daemon; `fb-idb` is the client that exposes `ui tap`.
Install the client in a venv rather than the system Python.

```sh
export IDB=/tmp/idbenv/bin/idb
export UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
$IDB connect $UDID
```

## Running the app first

The app has to be installed with its endpoints, and **both halves of that bite**
— see `CLAUDE.md`'s simulator recipe. In short: `rm -rf` the build directory or
`--dart-define` is silently stale, and `uninstall` before `install` or
`App.framework` is not replaced. Verify by counting the URL in the *installed*
`kernel_blob.bin`; do not trust the flag.

Uninstalling clears `shared_preferences`, so every clean install starts at
`0.2 Bienvenida`.

## Driving

```sh
python3 app/tool/device_ui.py labels                 # what is on screen
python3 app/tool/device_ui.py tap "Ajustes"
python3 app/tool/device_ui.py tap-last "Crear cuenta"
python3 app/tool/device_ui.py field 0 "someone@example.com"
python3 app/tool/device_ui.py wait "Revisa tu correo" 30
```

Read `labels` after every tap. It is the cheapest way to know where you are, and
it is how you find out a tap did nothing.

## Three traps, each of which cost a wrong tap

1. **A single character matches too much.** `tap "1"` matched `Reto 1` and hit
   the header, silently. Keys of one or two characters are matched exactly.
2. **A label can appear twice.** `Crear cuenta` is the screen's title *and* its
   button. The first match is the title; tapping it does nothing and looks like
   the app ignored you. Use `tap-last`.
3. **Text fields carry no label** — the eyebrow above them does. Tapping
   `CORREO` taps the caption. Use `field <index>`, which finds `AXTextField`
   elements in screen order.

## What it cannot do

- **Read an inbox.** The verification OTP is not recoverable from the database
  either: `neon_auth.verification.value` is 45 characters, hashed or encrypted,
  not the six digits. Ask the person for the code.
- **Touch system UI** — permission dialogs, Safari. That needs XCUITest.

## Watch from the inside too

A walkthrough that only looks at the screen misses half of what happened. While
driving, check the server log (`caller`, `operation`, `status` on every request)
and the database. The account run that proved this flow showed
`caller=session … status=404`, which is how we knew our own server had accepted
Neon's token rather than merely that the screen looked right.
