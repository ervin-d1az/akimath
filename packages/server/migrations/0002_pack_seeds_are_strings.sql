-- 0002 · a seed inside `template_refs` is a JSON string, never a JSON number.
--
-- `offline_packs.template_refs` is `jsonb`, and node-postgres parses jsonb with
-- `JSON.parse` (pg-types registers OID 3802 to it). Every seed above 2^53 that
-- goes in as a JSON number comes back out wrong:
--
--   9223372036854775807 -> 9223372036854776000
--   1477776061723855037 -> 1477776061723855000
--      9007199254740993 ->    9007199254740992
--
-- `issued_items.seed` is `bigint`, OID 20, which pg-types hands back as a raw
-- string — so the online path was always safe and only the offline one was not.
-- Same seed, two storage paths, one silently lossy, and the lossy one is the
-- path where the child has already been graded against the original item.
--
-- It is silent because splitmix64 avalanches: a seed off by one does not
-- rederive a similar item, it rederives an unrelated one, and every schema in
-- the frozen pack format is still perfectly happy with the result.
--
-- Forward-only, as an ALTER rather than an edit to 0001: that file has been
-- applied, and the runner refuses to start when a recorded checksum moves.
--
-- Found by an adversarial review of the `f1-core-rederivation` design, which
-- asked what would happen to a bigint on the way through jsonb. Nothing had
-- written a pack yet, so nothing was corrupted.

ALTER TABLE offline_packs
  ADD CONSTRAINT offline_packs_refs_are_an_array
  CHECK (jsonb_typeof(template_refs) = 'array');

ALTER TABLE offline_packs
  ADD CONSTRAINT offline_packs_seeds_are_strings
  CHECK (NOT jsonb_path_exists(template_refs, '$[*].seed ? (@.type() != "string")'));
