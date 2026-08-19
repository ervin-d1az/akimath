# Design

## D1 — A column, not a join table

One account, one player, in v1. `ARCHITECTURE.md` §5 scopes it to one device per player and the
frozen `Me` schema carries a single `playerId`, so a join table would model a cardinality the
response cannot express.

`UNIQUE` makes that explicit rather than hopeful. The day a parent needs two children under one
login it is a product decision, a new response shape and a migration that drops the constraint —
in that order, and none of it silently.

## D2 — No foreign key into `neon_auth`

The obvious move is `REFERENCES neon_auth."user"(id)`. It is wrong here for two reasons that have
nothing to do with correctness of data:

- **That schema belongs to the managed provider.** It migrates on their schedule. A constraint of
  ours pointing into it makes our tables a reason their migration cannot run, and we would find out
  during theirs, not ours.
- **Erasure does not want a cascade.** `DELETE /v1/me` is an explicit path under the
  `retention_job` role. A cascade is a deletion nobody wrote and nobody would see fire.

The absence is swept for, over every foreign key in `public` rather than over `players`, because
the rule is about the schema and the next table is where it would break.

## D3 — NOT NULL with no backfill

Safe only because the table is empty, and that was checked against the Neon project rather than
assumed: `select count(*) from players` → **0** on 2026-08-19.

A local database with rows in it will refuse the migration, and the refusal is right — a player
that predates the concept of an account has no value to invent. Drop it and migrate again.

## D4 — The gate this change had to widen, and the one it had to add

`f3-link-carries-the-band` asserted that **every** column the database will not fill in is a
required property of `POST /players/link`. `auth_user_id` is such a column and must **never** be in
that body, so the gate as written would have demanded the exact bug it exists to prevent.

Widened, not weakened: the exclusion is a named map from column to *where the value comes from
instead*, and it costs two further assertions —

- the body offers it **neither required nor optional** (the half that actually matters: a request
  that could name its own account lets any caller with any valid session claim somebody else's
  player);
- every entry in the exclusion map is a column the schema really requires, so a stale exclusion
  cannot quietly stop excusing anything.

## D5 — Applied to a real PostgreSQL, and deliberately not to Neon

Forward from an empty database on PostgreSQL 18: three migrations applied, second run reports
`applied: 0`, and `schema.sql` re-dumped byte-identical afterwards — so the snapshot is a function
of the migrations and of nothing else.

Neon was **not** touched. Recording `0003` in `schema_migrations` there makes that file's checksum
load-bearing forever, which is a production change and somebody's decision to make rather than an
agent's.
