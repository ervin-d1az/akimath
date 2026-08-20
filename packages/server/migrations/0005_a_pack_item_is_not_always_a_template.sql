-- 0005 · an item in a pack is not always something a template made.
--
-- `POST /attempts` grades a pack item by rederiving `template_refs[index]`.
-- That works for anything generated and cannot work for anything **authored**:
-- an authored item has no template reference, so `(pack_id, pack_index)` could
-- not address it and nothing could grade it.
--
-- Seventy of the eighty items the app ships are authored. So the pack a player
-- actually plays could never be synced — the account existed, the endpoint
-- existed, and the loop was closed only for content nobody prefers.
--
-- **The second way to know an answer is right is the digest the pack already
-- carries.** Every item in the frozen format has
-- `answer.digest = HMAC(pack_salt, canonical answer)`; the server keeps the
-- salt, computes the same HMAC over what was typed, and compares. It never
-- learns the answer — which is a stronger position than rederivation leaves it
-- in, and it is why this is a widening of the model rather than a hole in it.
--
-- **The column is renamed because the old name became a lie.** It holds
-- `{kind: "template", ...}` and `{kind: "digest", ...}` now, one per item and
-- in the same order, which is what makes `(pack_id, index)` address anything.
-- `packages/core`'s `manifest.ts` is the one definition of both shapes.
--
-- A rename carries its constraints with it: `offline_packs_refs_are_an_array`
-- and `offline_packs_seeds_are_strings` are rewritten by PostgreSQL to point at
-- the new name, and both still say what they said. The seed rule in particular
-- still bites, because a digest entry has no `seed` and the path predicate
-- passes over it.
--
-- **Safe on a table with rows in it**, unlike 0003 and 0004: a rename moves no
-- data and every existing entry keeps its meaning. It is verified empty anyway
-- (`select count(*) from offline_packs` → 0 on Neon, 2026-08-20), because
-- nothing has issued a pack outside a test.
--
-- Forward-only, as an ALTER: 0001 has been applied and the runner refuses to
-- start when a recorded checksum moves.

ALTER TABLE offline_packs
  RENAME COLUMN template_refs TO item_refs;

-- A rename carries the CHECKs and the foreign key, and leaves the NOT NULL
-- constraint's *name* behind: PostgreSQL 17 made those real catalogue entries
-- and does not rename them with the column. So the schema would have kept a
-- constraint called `offline_packs_template_refs_not_null` on a column called
-- `item_refs` — a name that says the wrong thing to whoever reads the dump
-- next, which is the only audience a constraint name has.
ALTER TABLE offline_packs
  RENAME CONSTRAINT offline_packs_template_refs_not_null
    TO offline_packs_item_refs_not_null;
