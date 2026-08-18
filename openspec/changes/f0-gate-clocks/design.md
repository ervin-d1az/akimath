# Design — gate deadlines

## D1 · The deadline cannot use GNU `timeout`

`timeout(1)` is coreutils and is **not present on macOS**, which is where the hook actually runs.
Depending on it would make the gate a no-op on the only machine that has it today — the same
class of failure as the upstream `fallow` hook, which resolved its binary in an interactive shell
and not in the hook's, and so failed open in silence on every commit.

The deadline is therefore implemented with shell primitives: the command runs in its own process
group, a watchdog sleeps for the deadline and signals that group, and the outcome is distinguished
by exit status. Killing the **group**, not the process, is what reaps grandchildren — a hung
`npm test` has a vitest worker under it, and killing only `npm` leaves the worker holding the
terminal.

## D2 · The message names the command, not the check set

`run_check` previously printed only on non-zero exit, so a hung check produced no output at all.
Restoring silence-on-success but adding a named failure keeps the quiet-when-green property while
removing the ambiguity: with four checks in the set, "the gate timed out" tells a developer almost
nothing, and "npm test (contract) ran past 600s and was killed" tells them where to look.

## D3 · A malformed override blocks instead of falling back

The obvious alternative — treat an unparseable `AKIMATH_GATE_TIMEOUT` as "use the default" — is
the wrong default for a gate. A typo would then silently restore exactly the unbounded behaviour
this change exists to remove, and it would do so invisibly. Failing closed on unreadable
configuration is the house rule already stated in `f0-invariant-tests` for an unlisted `dart:`
library.

## D4 · 600 seconds, and why the number is not the point

The default deadline is generous on purpose: it is a backstop against a hang, not a performance
budget. A check that legitimately approaches it is a separate problem to solve on its merits, and
the hook says so when it fires rather than inviting the number to be raised. CI's `timeout-minutes`
are sized per job instead, because the jobs differ by an order of magnitude — a paths filter is
seconds, a Flutter toolchain install and test run is minutes.

`testTimeout` at 5 s is the opposite end: unit tests in these two packages are milliseconds, so
five seconds is already three orders of magnitude of headroom and anything slower is a defect.

## D5 · Both sides of PURE

Nothing here is product code. The hook is a shell adapter around IO by definition, and the
workflow and vitest configuration are declarations. There is no policy to separate out, and
inventing a pure module for "is this string a positive integer" would be ceremony. The rule this
change answers to is PROC-5 — the rulebook, the hook and CI must name one set of commands — not
PURE-1.

## Alternatives rejected

- **A blanket `timeout-minutes` on the workflow.** Rejected: a five-minute cap on the paths filter
  and on the Flutter job cannot both be right, and one number would be sized for the slowest.
- **Relying on GitHub's six-hour default in CI and adding the clock only locally.** Rejected: the
  failure this change addresses reached CI too, and a six-hour job holds `gate` unreported the
  whole time.
- **Killing the process rather than the process group.** Rejected: it leaves the grandchildren
  running, which is how a "killed" check keeps holding a port or a lock.
