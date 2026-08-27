#!/usr/bin/env bash
#
# The local Postgres the database suites need, made ready — then, optionally,
# whatever you pass it, run with `TEST_DATABASE_URL` pointing at it.
#
#   ./scripts/local-database.sh              # ensure it, print what to export
#   ./scripts/local-database.sh vitest run   # ensure it, then run that
#
# **This exists because 129 of 454 tests skipped on every local run.** The
# suites read `TEST_DATABASE_URL` and `describeWithDatabase` degrades to
# `describe.skip` without it, so a developer with no Postgres saw a green 325
# and pushed; CI's `postgres:18` service container was the only place the other
# 129 ever executed. The recipe to fix that was four lines of comment in
# CLAUDE.md, which is a thing you read, not a thing you run.
#
# **It exports the variable rather than telling you to.** A script that prints
# an export line for the caller to copy fails open: forget it, or fumble the
# command substitution, and `TEST_DATABASE_URL` is empty and 129 tests skip
# again — the identical silence this is meant to end. So `npm run test:db`
# passes the command through here and the variable is set by construction.
#
# **It refuses a remote host, and that is not paranoia.** `test/support/
# database.ts` creates `akimath_test_w<worker>` off this URL's *server* and
# drops that database's `public` schema on every run. Pointed at Neon it would
# not wipe the Neon database — it would issue `CREATE DATABASE` against the
# production cluster and wipe whatever it managed to create. `.env.local`
# deliberately carries no `TEST_DATABASE_URL` for exactly this reason, and a
# guard here is what makes that deliberate absence survive someone exporting
# one by hand.
set -euo pipefail

# The local default. **Honoured if already set**, so CI's own value — a
# service container on localhost — is never clobbered by this script.
DEFAULT_URL="postgresql://localhost/akimath_dev"
URL="${TEST_DATABASE_URL:-$DEFAULT_URL}"

# **PostgreSQL 18's client tools first, not whichever formula is linked.**
# `brew link` points `psql`, `createdb` and `pg_dump` at one major, and on a
# machine carrying both 17 and 18 that is usually the older one. It costs the
# suites nothing — a 17 client talks to an 18 server fine — but `pg_dump`
# aborts outright on a server newer than itself ("server version mismatch"),
# which takes `npm run schema:dump` with it. Prepending the keg's bin makes the
# majors match by construction instead of by whatever was linked last.
if command -v brew >/dev/null 2>&1; then
  if PG18_PREFIX="$(brew --prefix postgresql@18 2>/dev/null)" \
     && [ -x "$PG18_PREFIX/bin/psql" ]; then
    PATH="$PG18_PREFIX/bin:$PATH"
    export PATH
  fi
fi

if ! command -v psql >/dev/null 2>&1; then
  cat >&2 <<'MESSAGE'
no psql on PATH, so there is no local PostgreSQL to point the suites at.

  brew install postgresql@18 && brew services start postgresql@18

18 because that is the major Neon provisioned and CI's service container
mirrors. Then run this again.
MESSAGE
  exit 1
fi

# The host, for the refusal below. An empty host is a Unix socket, which is as
# local as it gets.
host="$(
  printf '%s' "$URL" | sed -E 's#^[a-zA-Z+]+://##; s#[/?].*$##; s#^.*@##; s#:[0-9]+$##'
)"
case "$host" in
  "" | localhost | 127.0.0.1 | ::1 | "[::1]" | *.localhost) ;;
  *)
    cat >&2 <<MESSAGE
refusing to run the suites against a database that is not on this machine.

  host: $host

Every helper in test/support/database.ts drops and recreates a schema, and it
creates the databases it does that to. Against a managed provider that is a
write to production, not a test run. Unset TEST_DATABASE_URL to use the local
default ($DEFAULT_URL).
MESSAGE
    exit 1
    ;;
esac

if ! pg_isready --quiet ${host:+--host="$host"}; then
  cat >&2 <<MESSAGE
psql is installed but no server answered at ${host:-the local socket}.

  brew services start postgresql@18

MESSAGE
  exit 1
fi

# The database named in the URL, created if it is not there. **`psql -l`, not
# `psql -c` with no database**: connecting with neither `-d` nor `PGDATABASE`
# targets a database named after the current user, and a Homebrew cluster has
# no such database — the failure is `FATAL: database "you" does not exist`,
# which reads like the server is broken rather than like a default is missing.
database="$(printf '%s' "$URL" | sed -E 's#^[^/]*//[^/]*/##; s#[?].*$##')"
if ! psql -d postgres -tAc \
     "SELECT 1 FROM pg_database WHERE datname = '$database'" | grep -q 1; then
  createdb "$database"
  echo "created database $database" >&2
fi

server_version="$(psql -d postgres -tAc 'SHOW server_version')"
echo "postgres $server_version · $URL" >&2

if [ "$#" -eq 0 ]; then
  cat >&2 <<MESSAGE

Ready. Either run the suites through this script —

  npm run test:db

— or export it into your own shell:

  export TEST_DATABASE_URL=$URL
MESSAGE
  exit 0
fi

export TEST_DATABASE_URL="$URL"
exec "$@"
