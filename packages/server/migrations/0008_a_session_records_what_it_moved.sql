-- 0008 · a session records what it moved, because later nothing can.
--
-- `GET /me/history` has answered `ratingDelta: null` for every entry since it
-- was built. Until 0007 the reason was that no rating existed; after 0007 a
-- rating exists and the reason changed rather than went away:
--
--   **A delta is a difference between two instants and nothing recorded the
--   first.** `user_skills` holds only the current figure. No table snapshots a
--   rating per session. And it cannot be recomputed after the fact, because
--   the difficulty classes a session was rated against are themselves measured
--   from the players who met them (0007) — they move on the very next batch,
--   so replaying yesterday's answers against today's classes produces a
--   different number. That number would look like a measurement and would not
--   be one, which is the thing F4 was held back to avoid.
--
-- So the movement is written down at the one instant both ends of the
-- subtraction exist: inside the sync transaction, where `rateAttempts` has the
-- prior it was handed and the posterior it computed.
--
-- **One row per rating period, not per session.** `ARCHITECTURE.md` §3 makes
-- the session the rating period and `user_skills` is one row per
-- `(player_id, skill_id)`, so `ratingPeriods` already cuts a batch by session
-- *and* by skill — a session spanning two skills is two periods that move two
-- ratings by two different amounts. This table records what the engine did, so
-- its key is what the engine works in. Whether either figure can be *reported*
-- is `GET /me/history`'s question, and its answer is no: a single number for
-- such a session would have to sum two independent scales or pick one of them
-- by iteration order, the same `min(skill_id)` argument that already leaves
-- `skillId` null there.
--
-- **`rating_delta` and not `rating_before`/`rating_after`.** A session can be
-- synced in two batches — a device flushes what it has, the player answers
-- more of the same session, it flushes again — so the row is written twice.
-- Storing endpoints and keeping the first `before` with the last `after` would
-- attribute to this session anything that moved the rating in between, such as
-- a different session synced from another device. Adding what each batch
-- actually moved is exact whatever happens between them, so the upsert
-- accumulates and `created_at` stays at the first write. A *resent* batch adds
-- nothing at all: `insertAttempts` is `ON CONFLICT DO NOTHING` (0004), nothing
-- lands, no period is formed and no row is touched.
--
-- **Only a measured period leaves a row, and absent is how null is spelled.**
-- An answer against a class nobody has met teaches the class and does not move
-- the player (0007), so a session made only of those never runs the engine. It
-- gets no row, and `GET /me/history` reports null. Zero would be wrong for a
-- reason that is forced rather than chosen: `HistoryEntry.ratingDelta` is a
-- nullable *integer*, so a real measured change of a third of a point already
-- renders as `0` — and if an unmeasured session rendered `0` too, the two
-- facts the field has room for would be one value on the wire.
--
-- **`real`, matching `user_skills.rating` exactly.** The engine narrows every
-- figure it returns to float32 so that what is stored is what was computed; a
-- wider column would make the difference disagree with the two ratings it is
-- the difference of.
--
-- **It carries a `player_id`, so it is player data and is treated as such.**
-- Unlike `difficulty_ratings` and `template_stats`, which are aggregates over
-- everyone: this is one person's history. It cascades from `players`, so
-- `DELETE /me` erases it — `test/delete-me.test.ts` counts the rows rather
-- than trusting this line — and the retention job sweeps it on the *attempts*
-- cutoff, because a delta is an attribute of the history entry its attempts
-- produce and the two must not outlive each other.
--
-- Forward-only, as a new file: the earlier migrations have been applied and
-- the runner refuses to start when a recorded checksum moves.

CREATE TABLE session_deltas (
  player_id    uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  session_id   uuid        NOT NULL,
  skill_id     smallint    NOT NULL,
  rating_delta real        NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (player_id, session_id, skill_id)
);

-- The retention sweep reads `created_at` across every player, the same shape
-- as `attempts_created_idx` and `diag_events_created_idx`. The history join
-- needs no index of its own: it matches the primary key from the left.
CREATE INDEX session_deltas_created_idx ON session_deltas (created_at);

-- SELECT to answer the history, INSERT and UPDATE for the accumulating upsert
-- inside the sync transaction. No DELETE, like every other table: `app_request`
-- holds DELETE on nothing at all and `grants.test.ts` sweeps the schema to keep
-- it that way.
GRANT SELECT, INSERT, UPDATE ON session_deltas TO app_request;

-- SELECT as well as DELETE, and the SELECT is not decoration: the sweep's own
-- WHERE reads `created_at`, `player_id` and `session_id`, and PostgreSQL
-- requires SELECT on every column a DELETE's condition touches — including the
-- target table's. Granting DELETE alone passes a test suite that runs the job
-- as the owner and fails in the one process that runs it for real.
GRANT SELECT, DELETE ON session_deltas TO retention_job;
