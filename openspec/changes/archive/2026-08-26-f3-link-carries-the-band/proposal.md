# The link request carries the band

## Why

`players.age_band` is `NOT NULL` with no default. `POST /players/link` is the request that
creates a `players` row. The frozen `PlayerLink` schema carries `playerId` and nothing else.

That endpoint cannot be written. Not "is awkward to write" — the `INSERT` has no value for a
column the database will refuse the row without.

The hole is a leftover, not an oversight. Under `ARCHITECTURE.md` §5 as originally written, a
guest session synced first and wrote the row before any account existed, and the migration's own
comment says so: *"a guest writes this row at first sync, before any account exists, so a band
collected at `1.2 Crear cuenta` would arrive after the row."* **ADR 0002 removed guest sync.** An
unlinked device holds no session and leaves no row, so linking is now the row's creation and the
band has nowhere else to travel.

## What changes

- `PlayerLink` gains `ageBand`, required, over the same three values `Me` already reports.
- A gate that would have caught this: **every column of `players` the database will not fill in
  must be a required property of the link request**, asked of `information_schema` and of the
  committed `contract/openapi.json`.
- The `oasdiff` breaking-change gate gains a **label escape**, because this change is breaking and
  a gate with no way to say yes gets deleted rather than answered.

## Out of scope

The endpoint itself, and the session that authorises it. This change makes the endpoint
*writable*; it does not write it.

**The migration is not edited.** Its comment now describes a model ADR 0002 replaced, and it stays
as it is: `src/migrate.ts` checksums the bytes of every applied file, so correcting a comment
would desynchronise the Neon database that already ran it. The record lives in ADR 0002 and here.
