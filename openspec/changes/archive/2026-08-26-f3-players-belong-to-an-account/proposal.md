# A player belongs to an account

## Why

`POST /players/link` exists to attach a device-minted `player_id` to a Neon Auth account. There is
nowhere to record which account: `players` holds an id, a band and a timestamp.

So the endpoint still cannot be written — the same shape of hole `f3-link-carries-the-band` closed
on the request side, one column further in. And `GET /me` cannot be written either, because
"the player for this session" is a lookup with nothing to look up by.

## What changes

- `players.auth_user_id uuid NOT NULL`, `UNIQUE`.
- **It comes from the session, never from the body**, and that is now a test rather than an
  intention: the link-request gate excludes it by name, and a second half asserts `PlayerLink`
  cannot carry it.
- A sweep asserting **no foreign key anywhere in our schema points into `neon_auth`**.

## Out of scope

The endpoints. This is the column they need.

## What a human has to do

Two things, and neither can be done from here.

1. **Label the pull request `allow-protected-edit`.** It touches `migrations/**` and `schema.sql`.
2. **Run `npm run migrate` against Neon after it merges.** I did not: it is a production schema
   change, and recording `0003` in `schema_migrations` makes that file's checksum load-bearing
   forever. It is applied and verified against a local PostgreSQL 18 instead.
