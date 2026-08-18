#!/usr/bin/env bash
#
# Writes `schema.sql` — the committed snapshot of what the migrations produce.
#
# CI applies the migrations to an empty database, runs this, and fails on a
# diff. That gate is only worth having if the dump is a function of the schema
# and of nothing else, and out of the box it is not:
#
#   · pg_dump 17.6+ opens with `\restrict <random token>` and closes with the
#     matching `\unrestrict`. The token is regenerated on every run, so an
#     unpinned dump differs from itself. `--restrict-key` fixes it.
#   · The header records the server and client versions. Those churn on a patch
#     bump of either and say nothing about the schema, so they are stripped.
#   · **A managed provider adds its own roles and grants.** Dumping the Neon
#     database appends two `ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin ...
#     TO neon_superuser` lines — the platform's, not ours. They are a third
#     input to a file that is supposed to have one, and the check below refuses
#     them rather than letting them be committed.
#
# Without all three, the gate cries wolf and somebody deletes it within a week.
set -euo pipefail

: "${MIGRATE_DATABASE_URL:?set MIGRATE_DATABASE_URL to the database to dump}"

OUT="$(dirname "$0")/../schema.sql"

# Written to a temporary file and moved into place only once it has passed.
# `> "$OUT"` truncates before pg_dump has produced a byte, so a refusal — or a
# client that cannot reach the server at all — used to leave the committed
# snapshot destroyed and the working tree dirty for a reason unrelated to the
# schema.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

pg_dump \
  --schema-only \
  --no-owner \
  --no-comments \
  --restrict-key=akimath \
  "$MIGRATE_DATABASE_URL" \
  | grep -v '^-- Dumped from database version' \
  | grep -v '^-- Dumped by pg_dump version' \
  > "$TMP"

# **The snapshot must be portable, so it is dumped from plain PostgreSQL.**
#
# This is an exact rule and not a guess about hostnames: `migrations/` contains
# no `ALTER DEFAULT PRIVILEGES` and grants to exactly two roles it creates
# itself. Anything else in the dump was put there by whoever runs the database,
# so it belongs to the platform and not to this repository — which makes the
# check provider-agnostic, and keeps it working the day the provider changes.
foreign="$(
  {
    grep -n 'ALTER DEFAULT PRIVILEGES' "$TMP" || true
    grep -nE '^GRANT .* TO [A-Za-z_][A-Za-z0-9_]*;' "$TMP" \
      | grep -vE 'TO (app_request|retention_job|PUBLIC);' || true
  }
)"

if [ -n "$foreign" ]; then
  host="$(printf '%s' "$MIGRATE_DATABASE_URL" | sed -E 's#.*@([^/:]+).*#\1#')"
  cat >&2 <<MESSAGE
refusing to write schema.sql: the dump carries privileges this repository
never granted, so it describes the database's host as much as its schema.

  host: $host

$foreign

Only the two roles the migrations create — app_request and retention_job —
may appear, and nothing may set default privileges. A managed provider such
as Neon adds its own on top of yours, and committing them would make the CI
snapshot gate fail for everyone dumping from anywhere else.

Dump from a plain PostgreSQL instead:

  createdb akimath_snapshot
  MIGRATE_DATABASE_URL=postgresql://localhost/akimath_snapshot npm run migrate
  MIGRATE_DATABASE_URL=postgresql://localhost/akimath_snapshot npm run schema:dump

The committed snapshot has been left untouched.
MESSAGE
  exit 1
fi

mv "$TMP" "$OUT"
trap - EXIT
echo "wrote $(wc -l < "$OUT" | tr -d ' ') lines to schema.sql"
