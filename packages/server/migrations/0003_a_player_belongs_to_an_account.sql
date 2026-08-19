-- 0003 · a player belongs to an account, and the account is not in the body.
--
-- `POST /players/link` is the request that creates a `players` row (ADR 0002
-- removed the guest sync that used to write it first), and it exists to attach
-- a device-minted `player_id` to a Neon Auth account. There was nowhere to
-- record which account: `players` held an id, a band and a timestamp. The
-- endpoint could not be written.
--
-- **The account comes from the session, never from the request body.** The
-- frozen `PlayerLink` schema carries `playerId` and `ageBand` and must never
-- carry this — a body that names the account it is attaching to is an
-- account-takeover with extra steps. `test/link-request.test.ts` asserts both
-- halves: every column the caller must supply is in the body, and this one is
-- not.
--
-- **UNIQUE, because `GET /me` returns one player.** The frozen `Me` schema has a
-- single `playerId`, and §5's v1 scope is one device per player. The day a
-- parent needs two children under one account, that is a product decision, a
-- new response shape and a migration that drops this constraint — in that
-- order, and none of it silently.
--
-- **No foreign key into `neon_auth`.** That schema belongs to the managed
-- provider: it migrates on their schedule, and a constraint of ours pointing
-- into it would make our tables a reason their migration cannot run. Erasure
-- does not need one either — `DELETE /v1/me` is an explicit path under the
-- `retention_job` role, not a cascade we would only discover had fired.
-- `test/players.test.ts` asserts the absence, so nobody adds one on a quiet
-- afternoon.
--
-- **NOT NULL with no default and no backfill**, which is only safe because the
-- table is empty: verified against the Neon project before writing this
-- (`select count(*) from players` → 0, 2026-08-19). A local database with rows
-- in it will refuse this migration, and the refusal is correct — an existing
-- player predates the concept of an account and there is no value to invent.
-- Drop the local database and migrate again.
--
-- Forward-only, as an ALTER rather than an edit to 0001: that file has been
-- applied, and the runner refuses to start when a recorded checksum moves.

ALTER TABLE players
  ADD COLUMN auth_user_id uuid NOT NULL;

ALTER TABLE players
  ADD CONSTRAINT players_one_per_account UNIQUE (auth_user_id);
