#!/usr/bin/env bash
set -uo pipefail

# AkiMath commit/push gate for Claude Code (PreToolUse on Bash).
#
# Adapted from claude-craftsman-workflow's fallow-gate.sh. The mechanics are the
# ones that matter and they are preserved verbatim:
#
#   * fail OPEN (exit 0 + one stderr notice) on a runtime error — a missing
#     toolchain, an uninstalled dependency tree, a runner that cannot start.
#     **This half is switched off as of 2026-08-27**: AKIMATH_GATE_REQUIRED is
#     set in .claude/settings.json, so every one of those blocks instead. The
#     mechanism below is unchanged and the flag can be removed to get it back;
#     read the ENVIRONMENT entry for what it reaches and what it does not;
#   * fail CLOSED (exit 2) on a negative verdict — a real analyzer or test
#     failure, a wrong commit identity, a forbidden trailer;
#   * never block on findings inherited from the base (see "Baseline" below).
#
# A third category joined the two above when the deadline landed: a check that
# never returns fails CLOSED. It is not a missing toolchain — the tool started
# and ran — and the likeliest cause is a loop that does not terminate in the very
# code being committed, which is exactly what a gate exists to stop. A gate that
# hangs in silence is worse than no gate at all: the commit never returns, no
# verdict is ever printed, and nothing says which command is to blame.
#
# Exit 2 is the only code Claude Code treats as blocking. A plain exit 1 would
# be reported as a hook error and the tool call would proceed, which is exactly
# the silent-advisory failure this gate exists to avoid.
#
# WHAT REPLACED fallow AND WHY
# ----------------------------
# `fallow` analyzes TypeScript/JavaScript only. Run at the root of this repo it
# discovers 7 files — 5 of them in packages/server, plus app/web/index.html and
# a vitest config — and 0 of the 18 Dart files that are the bulk of the project
# today. A gate blind to app/lib/ is not a gate for AkiMath. It is also a
# homebrew global here, which is the precise failure mode adapting.md §5 warns
# about: the interactive terminal resolves it, a fresh clone has nothing.
#
# So the verdict now comes from the tools this project already owns and already
# commits tests for. The commands below are the same ones .github/workflows/ci.yml
# runs, so "green here" and "green in CI" mean the same thing.
#
#   app/**                flutter analyze --fatal-infos + flutter test
#   packages/server/**    npm run typecheck            + npm test  (in packages/server)
#   packages/contract/**  npm run typecheck            + npm test  (in packages/contract)
#   contract/**           npm run typecheck            + npm test  (in packages/contract)
#                                                      + npm test  (in packages/core)
#   packages/core/**      npm run typecheck            + npm test  (in packages/core)
#
# Each package is filtered on its own path. Until f0-pack-contract the filter
# fired on any packages/ path but only ever ran packages/server, so a
# contract-only change was gated by nothing at all.
#
# `dart run dart_code_linter:metrics` is in CI and deliberately not here.
# app/analysis_options.yaml carries the `dart_code_linter:` block now and
# .github/workflows/ci.yml runs the command with
# --set-exit-on-violation-level=warning, which is what makes it bite: without
# that flag it prints its violations and still exits 0. It stays out of this
# hook because this hook runs per commit and that step is CI's. This paragraph
# claimed the opposite until 2026-08-26.
#
# BASELINE — why "inherited findings" cannot block here
# ----------------------------------------------------
# Verified green at f8b24d6 (2026-08-15):
#
#   flutter analyze --fatal-infos ................ 0 issues
#   flutter test ................................. 34 passed
#   npm run typecheck (packages/server) .......... 0 errors
#   npm test (packages/server) ................... 3 passed
#
# packages/contract joined at f0-pack-contract (2026-08-16):
#
#   npm run typecheck (packages/contract) ........ 0 errors
#   npm test (packages/contract) ................. 189 passed
#
# The baseline is zero, so every finding this gate can report was introduced by
# the change in front of it. That is what makes a whole-tree check honest here
# and it is why no attribution pass is needed. The tradeoff is real and accepted:
# `flutter analyze` is whole-tree, not diff-scoped, so once the baseline stops
# being zero a stray lint in an untouched file would block unrelated commits.
# If that ever happens, fix the lint or update this header — do not weaken the
# gate silently.
#
# ENVIRONMENT
# -----------
#   AKIMATH_GATE_BASE      trunk used to scope the change when the current
#                          branch has no upstream. Default origin/main. Set in
#                          .claude/settings.json. It was origin/dev until
#                          2026-08-26, which stopped being the trunk at pull
#                          request #6 on 2026-08-17 — against that base every
#                          branch looks like 656 changed files, so the gate
#                          could never scope itself to the change under it.
#   AKIMATH_COMMIT_EMAIL   required git commit identity. Default
#                          geineryodan@gmail.com.
#   AKIMATH_FLUTTER_BIN    absolute path to flutter, when PATH does not carry it.
#   AKIMATH_NPM_BIN        absolute path to npm, when PATH does not carry it.
#                          Neither is set, and neither needs to be: a hook does
#                          not source a shell profile, it inherits Claude Code's
#                          own environment, and that PATH was read off the
#                          running process on 2026-08-27 — it carries
#                          /Users/ervin/develop/flutter/bin and the nvm bin
#                          directory that owns npm. The nvm half is the one that
#                          could plausibly have been missing, and is not. These
#                          two belong in .claude/settings.local.json when a
#                          machine does need them; they are absolute paths, so
#                          they never belong in this committed settings.json.
#   AKIMATH_GATE_REQUIRED  set to 1 in .claude/settings.json since 2026-08-27,
#                          which is what turns every fail_open() into a block:
#                          flutter or npm unresolvable, a package's node_modules
#                          missing, a check directory absent, a runner exiting
#                          126/127. It was documented for weeks as something to
#                          turn on "once the environment is settled" and was
#                          never set, which left the gate reporting green for
#                          the one reason it must never report green.
#                          **Two fail-open exits it does not reach**, and the
#                          first of them on purpose: the `jq` guard and a failed
#                          `cd` into PROJECT_DIR both exit 0 further up, before
#                          fail_open exists. jq has to stay that way — without it
#                          the payload cannot be parsed, so the gate cannot tell
#                          a `git commit` from an `ls`, and blocking there would
#                          block every Bash call in the session rather than a
#                          commit. So "a missing toolchain blocks" is true of
#                          flutter and npm and is deliberately untrue of jq.
#                          **The cost, which is a prerequisite and not a
#                          surprise**: a subagent worktree is a fresh checkout
#                          and carries no packages/*/node_modules, so wherever
#                          this hook does fire, a commit from a worktree that
#                          touches packages/** or contract/** blocks until
#                          `npm ci` has run in the package the change lands in.
#                          That is the intended reading — those suites were
#                          never running there — but it is work somebody now has
#                          to do rather than skip silently. It is also moot in
#                          the sessions described below, where the hook does not
#                          run at all.
#                          Worth knowing when reading a "silent" gate: Claude
#                          Code surfaces a hook's stderr to the agent only on
#                          exit 2, so a fail-open notice and a clean pass look
#                          identical from inside a session. Blocking is the only
#                          state that can speak for itself.
#   AKIMATH_GATE_DEBUG     when set, log the commands the gate skipped.
#   AKIMATH_GATE_TIMEOUT   seconds any single check may run before it is killed
#                          and the commit is blocked. Default 600 — an order of
#                          magnitude above anything this gate runs today (the
#                          whole packages/contract suite is 0.8s) so it can only
#                          ever fire on a hang, never on a slow machine.
#
# MEASURED 2026-08-27, AND NOT FIXED HERE — THIS HOOK DOES NOT RUN IN A SUBAGENT
# WORKTREE
# -----------------------------------------------------------------------------
# The flag above closes the fail-open hole. It cannot close a hole one level up.
# Inside a worktree-isolated subagent session (the Agent tool's `isolation:
# worktree`), the PreToolUse hook never executes at all. Measured, not inferred:
# an unconditional `date >> <file>` was put on the first line of this script and
# the file was never created across several Bash tool calls, and two commands
# this script blocks on when run by hand — one carrying a Co-Authored-By
# trailer — passed straight through. The settings `env` block does reach those
# sessions: `printenv AKIMATH_GATE_BASE` answers origin/main there, so the
# settings file is being read.
#
# WHY it does not run was not measured, and there are two candidates. The one
# with direct evidence is the hook's own command line, `bash
# "$CLAUDE_PROJECT_DIR"/.claude/hooks/verify-gate.sh`: `printenv
# CLAUDE_PROJECT_DIR` answers nothing in a worktree session, and an unset one
# expands to `bash /.claude/hooks/verify-gate.sh`, which is not found, exits 127
# and is reported as a non-blocking hook error while the tool call proceeds —
# every observation above, with the `hooks` block working perfectly. That would
# be a one-line fix here, and note the `dirname "${BASH_SOURCE[0]}"/../..`
# fallback further down cannot help: it runs inside a script that was never
# located. The weakness of that candidate, stated so nobody chases it as fact:
# CLAUDE_PROJECT_DIR is set for hook commands specifically, so its absence from
# a Bash tool subprocess is suggestive and not proof. The other candidate is
# that the `hooks` block simply does not apply to these sessions. They cannot be
# told apart from inside one, because a settings change is not reloaded
# mid-session. Check it from a main session instead: `echo git commit
# Co-Authored-By: x` blocks if this hook fires there.
#
# Either candidate, and not fail-open, explains an agent reporting
# "the hook produced no output at all". Note that no output is also exactly what
# a clean pass looks like, so the report on its own distinguishes nothing. What
# is verified either way: a worktree agent's commits are not gated, so the pull
# request and .github/workflows/ci.yml are the only checks those commits meet.
# Whether the same is true of the main interactive session was not measured and
# is not claimed. Fixing it is out of this change's scope.

BASE_REF="${AKIMATH_GATE_BASE:-origin/main}"
REQUIRED_EMAIL="${AKIMATH_COMMIT_EMAIL:-geineryodan@gmail.com}"
TIMEOUT_SECONDS="${AKIMATH_GATE_TIMEOUT:-600}"
# Seconds between the polite SIGTERM and the SIGKILL, so a runner that traps
# TERM gets to flush what it had before the group is torn down.
GRACE_SECONDS=5

if ! command -v jq >/dev/null 2>&1; then
  echo "verify-gate: jq not on PATH, skipping." >&2
  exit 0
fi

INPUT="$(cat)"
CMD="$(jq -r '.tool_input.command // empty' <<<"$INPUT")"

# Tokenize instead of matching one regex so git-level options between `git` and
# the subcommand (git -c k=v commit, git -C dir push, git --no-pager commit)
# still route into the gate, while subcommand lookalikes in arguments
# (git log commit-message.txt) do not. Kept verbatim from fallow-gate.sh.
is_git_write_command() {
  local cmd="$1" segment
  # Control operators separate simple commands; each becomes its own line.
  while IFS= read -r segment; do
    # Intentional word splitting; globbing is disabled by the caller.
    # shellcheck disable=SC2086
    set -- $segment
    while [ "$#" -gt 0 ]; do
      if [ "$1" != "git" ]; then
        shift
        continue
      fi
      shift
      while [ "$#" -gt 0 ]; do
        case "$1" in
          commit | push)
            return 0
            ;;
          -c | -C | --git-dir | --work-tree | --namespace | --config-env | --super-prefix | --exec-path | --list-cmds | --attr-source)
            # Global option whose value arrives as the next word.
            shift
            [ "$#" -gt 0 ] && shift
            ;;
          -*)
            # Value-less global option (--no-pager) or inline-value form
            # (--git-dir=/x, -cuser.name=x).
            shift
            ;;
          *)
            # A different subcommand; resume scanning for a later `git` word.
            break
            ;;
        esac
      done
    done
  done < <(printf '%s\n' "$cmd" | tr ';|&()' '\n\n\n\n\n')
  return 1
}

set -f
if is_git_write_command "$CMD"; then
  GIT_WRITE=1
else
  GIT_WRITE=0
fi
set +f

if [ "$GIT_WRITE" -eq 0 ]; then
  if [ -n "${AKIMATH_GATE_DEBUG:-}" ]; then
    echo "verify-gate: not a git commit/push, skipping." >&2
  fi
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
cd "$PROJECT_DIR" || {
  echo "verify-gate: cannot enter $PROJECT_DIR, skipping." >&2
  exit 0
}

block() {
  printf 'verify-gate: BLOCKED — %s\n' "$1" >&2
  shift
  for line in "$@"; do
    printf 'verify-gate: %s\n' "$line" >&2
  done
  exit 2
}

fail_open() {
  if [ -n "${AKIMATH_GATE_REQUIRED:-}" ]; then
    block "$1" "AKIMATH_GATE_REQUIRED is set, so this is treated as a failure."
  fi
  printf 'verify-gate: %s — skipping the gate.\n' "$1" >&2
  exit 0
}

# --- Identity checks -------------------------------------------------------
# Two AkiMath rules that are pure string comparisons and rot the moment nobody
# looks: the commit identity, and the Co-Authored-By trailer the project bans
# outright. Both are verdicts, so both fail closed.
#
# Known gap, stated rather than papered over: the trailer check greps the command
# string, so `git commit -F message.txt` or a message assembled by a heredoc slips
# past it. It catches the common case — an agent appending the trailer inline —
# and nothing else. The rule still lives in the rulebook; this is a reminder, not
# an enforcement.

if printf '%s' "$CMD" | grep -qi 'co-authored-by'; then
  block "the command carries a Co-Authored-By trailer." \
    "AkiMath commits never credit a co-author. Remove the trailer and retry."
fi

CONFIGURED_EMAIL="$(git config user.email 2>/dev/null || true)"
if [ "$CONFIGURED_EMAIL" != "$REQUIRED_EMAIL" ]; then
  block "git config user.email is '${CONFIGURED_EMAIL:-<unset>}', expected '$REQUIRED_EMAIL'." \
    "Fix it with: git config user.email $REQUIRED_EMAIL"
fi

# --- What changed ----------------------------------------------------------
# Three targeted commands instead of parsing `git status --porcelain`, whose
# rename (`R  old -> new`) and quoted-path forms are easy to mis-split. Every
# call is guarded: `set -e` is off, but a bare failure here must not look like
# "nothing changed".
#
# `-c core.quotePath=false` on every one of them, and it is load-bearing. With
# git's default (quotePath=true) any path containing a non-ASCII byte comes back
# C-quoted with a leading double quote — `"app/lib/\303\261andu.dart"` — which the
# `^app/` and `^packages/` patterns below then fail to match. If every changed
# path in a commit were non-ASCII, the gate would find "nothing to check" and
# exit 0: a silent no-gate, the one failure this hook exists to prevent. This is
# an es-MX project; accented filenames are not hypothetical. Regression check:
#
#   touch "app/lib/probe/ñandú.dart"
#   git -c core.quotePath=false ls-files --others --exclude-standard | grep '^app/'
#
# must print the path (without the flag it prints nothing).

collect_changed_paths() {
  {
    git -c core.quotePath=false diff --cached --name-only 2>/dev/null || true
    git -c core.quotePath=false diff --name-only 2>/dev/null || true
    git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null || true
    if git rev-parse --verify --quiet '@{u}' >/dev/null 2>&1; then
      git -c core.quotePath=false diff --name-only '@{u}...HEAD' 2>/dev/null || true
    elif git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
      git -c core.quotePath=false diff --name-only "$BASE_REF...HEAD" 2>/dev/null || true
    fi
  } | sort -u
}

CHANGED="$(collect_changed_paths)"

touches() {
  printf '%s\n' "$CHANGED" | grep -q "$1"
}

RUN_DART=0
RUN_TS=0
RUN_CONTRACT=0
RUN_CORE=0
touches '^app/' && RUN_DART=1
touches '^packages/server/' && RUN_TS=1
touches '^packages/contract/' && RUN_CONTRACT=1
touches '^packages/core/' && RUN_CORE=1
# contract/ holds the emitted artifacts packages/contract owns, so a change
# there is gated by that package's suite.
touches '^contract/' && RUN_CONTRACT=1
# **Both sides of the edge.** packages/core holds the frozen contract as a
# devDependency and its parity suite checks core's output against it, so a
# change to the contract or to its emitted artifacts has to run core's tests
# too. A gate that watches one side of an edge reports green while the other
# drifts — the same reasoning as the `core` filter in ci.yml.
touches '^packages/contract/' && RUN_CORE=1
touches '^contract/' && RUN_CORE=1
# The reference template reproduces a named item from the shipped pack.
touches '^app/assets/packs/' && RUN_CORE=1

if [ "$RUN_DART" -eq 0 ] && [ "$RUN_TS" -eq 0 ] && [ "$RUN_CONTRACT" -eq 0 ] && [ "$RUN_CORE" -eq 0 ]; then
  if [ -n "${AKIMATH_GATE_DEBUG:-}" ]; then
    echo "verify-gate: no app/ or packages/ paths in the change, nothing to check." >&2
  fi
  exit 0
fi

# --- Runner ----------------------------------------------------------------
# Exit 126/127 means the runner itself could not start (not executable / not
# found). That is a runtime error and fails open. Anything else non-zero is a
# verdict from a tool that did run, and blocks. A check that outlives
# TIMEOUT_SECONDS is killed and blocks too, naming itself as it goes.

TMP_OUT="$(mktemp)"
TIMED_OUT_FLAG="$TMP_OUT.timed-out"
trap 'rm -f "$TMP_OUT" "$TIMED_OUT_FLAG"' EXIT

case "$TIMEOUT_SECONDS" in
  '' | 0 | *[!0-9]*)
    block "AKIMATH_GATE_TIMEOUT is '$TIMEOUT_SECONDS', which is not a positive whole number of seconds." \
      "The deadline is what keeps a hung check from hanging the commit, so a gate that cannot read it does not run."
    ;;
esac

# Runs one command under a deadline, and returns its exit status.
#
# `timeout(1)` is not the answer here: it is GNU coreutils and macOS ships
# neither it nor `gtimeout` (verified — `command -v timeout gtimeout` finds
# nothing on this machine), and this hook only ever runs on a developer's
# machine. One implementation that works everywhere beats two where the second
# is never exercised.
#
# The command goes into its own process group (`set -m` gives a background job
# one) so the watchdog can kill the whole tree. Killing the direct child alone
# is not enough: `npm test` is the parent of vitest, which is the parent of its
# workers, and those workers outlive their grandparent — measured, they stayed
# alive and greppable until the group form reaped them. The watchdog gets a
# group of its own for the same reason: its own `sleep` would otherwise outlive
# it as an orphan.
#
# The flag file, not the exit status, is what says "this was a timeout": a
# process killed by SIGTERM exits 143, and so could a runner that took the
# signal from somewhere else.
run_with_deadline() {
  local dir="$1"
  shift
  rm -f "$TIMED_OUT_FLAG"
  set -m
  (cd "$dir" && exec "$@") >"$TMP_OUT" 2>&1 &
  local job_pid=$!
  (
    sleep "$TIMEOUT_SECONDS"
    kill -0 "$job_pid" 2>/dev/null || exit 0
    : >"$TIMED_OUT_FLAG"
    kill -TERM -- "-$job_pid" 2>/dev/null
    sleep "$GRACE_SECONDS"
    kill -KILL -- "-$job_pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  local watchdog_pid=$!
  set +m
  local status=0
  wait "$job_pid" 2>/dev/null || status=$?
  kill -- "-$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null
  return "$status"
}

run_check() {
  local label="$1" dir="$2"
  shift 2
  if [ ! -d "$dir" ]; then
    fail_open "$label cannot run: $dir does not exist"
  fi
  local status=0
  run_with_deadline "$dir" "$@" || status=$?
  if [ "$status" -eq 0 ]; then
    return 0
  fi
  if [ -f "$TIMED_OUT_FLAG" ]; then
    {
      printf 'verify-gate: BLOCKED — %s ran past %ss and was killed.\n' "$label" "$TIMEOUT_SECONDS"
      printf 'verify-gate: a check that never returns makes a commit that never returns.\n'
      printf 'verify-gate: suspect a loop with no exit in what you are about to commit.\n'
      printf 'verify-gate: raise AKIMATH_GATE_TIMEOUT only once you know the command is honestly that slow.\n'
      printf 'verify-gate: last 40 lines it managed to print follow.\n'
      tail -n 40 "$TMP_OUT"
    } >&2
    exit 2
  fi
  if [ "$status" -eq 126 ] || [ "$status" -eq 127 ]; then
    fail_open "$label could not start (exit $status)"
  fi
  {
    printf 'verify-gate: BLOCKED — %s failed (exit %s).\n' "$label" "$status"
    printf 'verify-gate: last 40 lines follow.\n'
    tail -n 40 "$TMP_OUT"
  } >&2
  exit 2
}

if [ "$RUN_DART" -eq 1 ]; then
  FLUTTER="${AKIMATH_FLUTTER_BIN:-}"
  if [ -z "$FLUTTER" ]; then
    FLUTTER="$(command -v flutter 2>/dev/null || true)"
  fi
  if [ -z "$FLUTTER" ] || [ ! -x "$FLUTTER" ]; then
    fail_open "app/ changed but flutter is not resolvable (set AKIMATH_FLUTTER_BIN)"
  fi
  run_check "flutter analyze --fatal-infos" app "$FLUTTER" analyze --fatal-infos
  # failures-only keeps the blocked report readable: the default reporter emits
  # one progress line per test and buries the failure under 30 lines of noise.
  run_check "flutter test" app "$FLUTTER" test --reporter failures-only
fi

if [ "$RUN_TS" -eq 1 ]; then
  NPM="${AKIMATH_NPM_BIN:-}"
  if [ -z "$NPM" ]; then
    NPM="$(command -v npm 2>/dev/null || true)"
  fi
  if [ -z "$NPM" ] || [ ! -x "$NPM" ]; then
    fail_open "packages/ changed but npm is not resolvable (set AKIMATH_NPM_BIN)"
  fi
  if [ ! -d packages/server/node_modules ]; then
    fail_open "packages/server/node_modules is missing (run npm ci there)"
  fi
  run_check "npm run typecheck" packages/server "$NPM" run typecheck
  run_check "npm test" packages/server "$NPM" test
fi

if [ "$RUN_CONTRACT" -eq 1 ]; then
  NPM="${AKIMATH_NPM_BIN:-}"
  if [ -z "$NPM" ]; then
    NPM="$(command -v npm 2>/dev/null || true)"
  fi
  if [ -z "$NPM" ] || [ ! -x "$NPM" ]; then
    fail_open "packages/contract changed but npm is not resolvable (set AKIMATH_NPM_BIN)"
  fi
  if [ ! -d packages/contract/node_modules ]; then
    fail_open "packages/contract/node_modules is missing (run npm ci there)"
  fi
  run_check "npm run typecheck (contract)" packages/contract "$NPM" run typecheck
  run_check "npm test (contract)" packages/contract "$NPM" test
fi

if [ "$RUN_CORE" -eq 1 ]; then
  NPM="${AKIMATH_NPM_BIN:-}"
  if [ -z "$NPM" ]; then
    NPM="$(command -v npm 2>/dev/null || true)"
  fi
  if [ -z "$NPM" ] || [ ! -x "$NPM" ]; then
    fail_open "packages/core changed but npm is not resolvable (set AKIMATH_NPM_BIN)"
  fi
  if [ ! -d packages/core/node_modules ]; then
    fail_open "packages/core/node_modules is missing (run npm ci there)"
  fi
  run_check "npm run typecheck (core)" packages/core "$NPM" run typecheck
  run_check "npm test (core)" packages/core "$NPM" test
fi

exit 0
