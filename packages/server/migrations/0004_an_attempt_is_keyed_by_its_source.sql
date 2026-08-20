-- 0004 · an attempt is keyed by its source, and remembers which session it was in.
--
-- Two changes, one subject: what makes an attempt the same attempt.
--
-- **A retry used to record the batch twice.** `POST /attempts` takes no
-- `Idempotency-Key` — the frozen contract puts one on `POST /players/link` and
-- not here — and there was no unique key to hang an `ON CONFLICT` on. A client
-- whose sync timed out and resent would double every row it carried, and
-- `attempts` accepts no UPDATE and no DELETE from the request path, so nothing
-- could clean it up. The counts would be wrong and, once rating exists, so
-- would the rating.
--
-- The fix needed a product decision rather than a schema one: the natural key
-- can only be the source if answering the same item twice is *not* a thing the
-- product does. Decided 2026-08-19 — **one attempt per item**. Replaying a
-- series is not a feature, and if it becomes one this constraint is what has to
-- be argued with, which is the right place for that argument to happen.
--
-- Partial indexes, because `attempts_one_source` makes exactly one of the two
-- halves non-null on every row: a full index over `(pack_id, pack_index)` would
-- treat every issued-item row as `(NULL, NULL)`, and Postgres holds NULLs
-- distinct, so it would neither collide nor protect.
--
-- **`session_id` is what a history entry is grouped by.** Every submission
-- carries one — `AttemptSubmission.sessionId` has been in the frozen contract
-- since the freeze — and the table has never had a column for it, so
-- `GET /me/history` had nothing to build a series out of. `packages/contract`
-- says as much next to the field: "the frozen `attempts` table has no such
-- column, so today it groups the sync batch in flight and is not persisted.
-- Where it should live is an open question." This is the answer.
--
-- **NOT NULL with no default and no backfill**, which is only safe because the
-- table is empty: verified against the Neon project before writing this
-- (`select count(*) from attempts` → 0, 2026-08-19). A database with rows in it
-- will refuse this migration, and the refusal is correct — an attempt recorded
-- before sessions were persisted has no session to invent.
--
-- Forward-only, as an ALTER: 0001 has been applied, and the runner refuses to
-- start when a recorded checksum moves.

ALTER TABLE attempts
  ADD COLUMN session_id uuid NOT NULL;

CREATE INDEX attempts_session_idx ON attempts (player_id, session_id);

CREATE UNIQUE INDEX attempts_one_per_issued_item
  ON attempts (issued_item_id)
  WHERE issued_item_id IS NOT NULL;

CREATE UNIQUE INDEX attempts_one_per_pack_item
  ON attempts (pack_id, pack_index)
  WHERE pack_id IS NOT NULL;
