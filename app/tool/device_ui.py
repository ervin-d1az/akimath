#!/usr/bin/env python3
"""Drive the app on a booted simulator, by accessibility label.

**Why this exists.** `flutter test integration_test` drives the app from the
inside and is the right tool for anything you want to keep. This is for the
other half: walking a flow the way a person would, seeing what is on screen,
and reacting to it — reviewing a screen, reproducing a report, or getting
through a step no test can automate.

It taps by **label, not by pixel**. A coordinate breaks the moment a button
moves, and the failure reads "nothing happened"; a label breaks only when the
element is really gone, which is the failure worth hearing about.

    export IDB=path/to/idb            # see the device-walkthrough skill
    export UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}')

    python3 app/tool/device_ui.py labels            # what is on screen
    python3 app/tool/device_ui.py tap "Ajustes"
    python3 app/tool/device_ui.py tap-last "Crear cuenta"
    python3 app/tool/device_ui.py field 0 "someone@example.com"
    python3 app/tool/device_ui.py wait "Revisa tu correo" 30

Three traps, each of which cost a wrong tap the first time:

1. **A single character must match exactly.** `tap "1"` matched `Reto 1` and hit
   the header. Keys of one or two characters are matched exactly.
2. **A label can appear twice.** `Crear cuenta` is the screen's title *and* its
   button; the first match is the title and tapping it does nothing. `tap-last`
   takes the bottom-most.
3. **Text fields have no label.** The eyebrow above them does. Address them by
   index with `field`, which finds `AXTextField` elements in screen order.
"""
import json
import os
import subprocess
import sys
import time

IDB = os.environ.get("IDB", "idb")
UDID = os.environ.get("UDID", "")


def _idb(*args: str) -> str:
    if not UDID:
        sys.exit("set UDID to a booted simulator (xcrun simctl list devices booted)")
    result = subprocess.run(
        [IDB, *args, "--udid", UDID], capture_output=True, text=True
    )
    return result.stdout.strip()


def tree() -> list:
    """Every accessibility element on screen, as the device reports it."""
    out = _idb("ui", "describe-all")
    return json.loads(out) if out.startswith("[") else []


def labels() -> list:
    return [e.get("AXLabel") or "" for e in tree() if e.get("AXLabel")]


def _centre(frame: dict) -> tuple:
    return (
        int(frame["x"] + frame["width"] / 2),
        int(frame["y"] + frame["height"] / 2),
    )


def find(label: str, last: bool = False):
    # Exact for one or two characters: `1` must not match `Reto 1`.
    exact = len(label) <= 2
    def matches(element: dict) -> bool:
        got = element.get("AXLabel") or ""
        return got == label if exact else label in got

    hits = [e for e in tree() if matches(e)]
    if not hits:
        return None
    hits.sort(key=lambda e: e["frame"]["y"])
    return _centre(hits[-1 if last else 0]["frame"])


def wait_for(label: str, timeout: float = 25, last: bool = False):
    end = time.time() + timeout
    while time.time() < end:
        found = find(label, last)
        if found:
            return found
        time.sleep(0.7)
    return None


def tap(label: str, timeout: float = 25, last: bool = False) -> None:
    point = wait_for(label, timeout, last)
    if not point:
        print(f"  ✗ no «{label}». on screen: {labels()[:12]}")
        sys.exit(1)
    _idb("ui", "tap", str(point[0]), str(point[1]))
    print(f"  tapped «{label}» at {point}")
    time.sleep(0.9)


def field(index: int, text: str) -> None:
    """Type into the nth text field, counted down the screen."""
    fields = [e for e in tree() if e.get("role") == "AXTextField"]
    if index >= len(fields):
        sys.exit(f"  ✗ only {len(fields)} text field(s) on screen")
    point = _centre(fields[index]["frame"])
    _idb("ui", "tap", str(point[0]), str(point[1]))
    time.sleep(0.8)
    _idb("ui", "text", text)
    print(f"  typed {len(text)} characters into field {index}")
    time.sleep(0.6)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    command = sys.argv[1]
    if command == "labels":
        for label in labels():
            print(f"  {label}")
    elif command == "tap":
        tap(sys.argv[2])
    elif command == "tap-last":
        tap(sys.argv[2], last=True)
    elif command == "field":
        field(int(sys.argv[2]), sys.argv[3])
    elif command == "wait":
        timeout = float(sys.argv[3]) if len(sys.argv) > 3 else 25
        print("  yes" if wait_for(sys.argv[2], timeout) else "  no")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
