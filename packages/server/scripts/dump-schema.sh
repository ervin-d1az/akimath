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
#
# Without both, the gate cries wolf and somebody deletes it within a week.
set -euo pipefail

: "${MIGRATE_DATABASE_URL:?set MIGRATE_DATABASE_URL to the database to dump}"

OUT="$(dirname "$0")/../schema.sql"

pg_dump \
  --schema-only \
  --no-owner \
  --no-comments \
  --restrict-key=akimath \
  "$MIGRATE_DATABASE_URL" \
  | grep -v '^-- Dumped from database version' \
  | grep -v '^-- Dumped by pg_dump version' \
  > "$OUT"

echo "wrote $(wc -l < "$OUT" | tr -d ' ') lines to schema.sql"
