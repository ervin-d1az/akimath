-- 0007 · a difficulty class has a rating, measured from the players who met it.
--
-- Glicko rates a player against an *opponent*, and a player here answers an
-- item. Something has to supply the item's strength, and `ARCHITECTURE.md` §3
-- deliberately left that open: `packages/core`'s `glicko.ts` says "core decides
-- nothing about where an opponent rating comes from", because nothing in the
-- frozen schema supplied one.
--
-- **What plays the opponent is the difficulty class `(skill_id, ladder_step)`,
-- and its rating is measured rather than declared.** That distinction is the
-- whole reason this table exists instead of a constant in a module:
--
--   · `ladder_step` is an *identity*, not a rating. It is a 1..20 ordinal the
--     content author writes, required on every pack item by the frozen pack
--     schema and recorded on every `issued_items` row. Mapping it onto the
--     rating scale — "step 10 is 1500, a step is worth 50 points" — would be
--     two numbers nothing in this database supports, which is exactly the
--     invented scale F4 was held back to avoid.
--   · So the step names the bucket and the *players* set its rating. A class is
--     rated by the same Glicko engine and on the same scale as a player, from
--     the mirrored outcome of every answer against it: a class that beats
--     strong players is strong. The only anchor is Glickman's own 1500/350 for
--     an entity nobody has met, which is already committed code with a citation
--     rather than a figure chosen tonight.
--
-- **Why not `template_stats`, which is right here and unwritten.** Its key is
-- `(template_id, template_version)`, and *no item in production has one*: the
-- only issuable pack is a copy of the shipped content, whose eighty items are
-- all `{kind: "digest"}` manifest entries because authored content cannot be
-- rederived (0005). A calibration keyed on templates could therefore never
-- acquire a single row. It is left untouched and still unwritten, for the day
-- `GET /items/next` issues template items.
--
-- **Why Glicko state and not four aggregates.** `template_stats` records
-- `attempts`, `correct`, `sum_expected` and `sum_user_rating`, and those can
-- produce a difficulty *estimate* but not the *deviation* Glicko's `Outcome`
-- requires beside it — a confidence derived from a row count would be one more
-- invented constant. A rating and a deviation are what the engine consumes and
-- what it already knows how to update, so the class is stored the way a player
-- is. `deviation` is also the honest answer to "how much evidence is behind
-- this", which is why there is no attempt counter next to it: two columns
-- answering one question is one column that can disagree.
--
-- **No decay column and no decay.** `decay` models a person changing while
-- nobody was watching. An item does not get harder while it sits in a pack, so
-- the class's uncertainty only ever shrinks, and it shrinks from evidence.
--
-- **No `player_id`, deliberately, and therefore no retention grant.** This is an
-- aggregate over everyone who met the class; erasing one player must not empty
-- it, and the retention job must not delete from it. Same shape as
-- `template_stats`, and `test/delete-me.test.ts` holds both to surviving
-- erasure. Nothing exposes this table through any endpoint.
--
-- `real`, matching `user_skills.rating` and `.deviation` exactly: the engine
-- narrows every figure it returns to float32 so that what is stored is what was
-- computed, and a wider column here would silently make the two ends of one
-- calculation disagree.
--
-- Forward-only, as a new file: 0001 has been applied and the runner refuses to
-- start when a recorded checksum moves.

CREATE TABLE difficulty_ratings (
  skill_id    smallint    NOT NULL,
  ladder_step smallint    NOT NULL,
  rating      real        NOT NULL,
  deviation   real        NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (skill_id, ladder_step)
);

-- SELECT to read the prior, INSERT and UPDATE to write the posterior — the
-- upsert runs inside the sync transaction, as `ARCHITECTURE.md` §5 describes.
-- No DELETE, for `app_request` or for anyone: a class that has been met cannot
-- become unmet, and `grants.test.ts` sweeps every table for the first rule.
GRANT SELECT, INSERT, UPDATE ON difficulty_ratings TO app_request;
