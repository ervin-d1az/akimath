# The ten changes that are complete and cannot be archived

Every change in this directory is **implemented and merged**. `openspec list` reports each of
them `✓ Complete`, and `openspec archive` refuses all ten for one reason: a
`## MODIFIED Requirements` block names a requirement header that **no delta anywhere ever ADDs**.
The tool aborts rather than invent the requirement it was asked to modify — `Aborted. No files
were changed.` — which is the right call, and it is why the sweep of 2026-08-26 archived 45 of 55
and stopped here.

**Re-running the sweep in a different order will not help.** Across all deltas, 21 of the 22
MODIFIED requirements have no ADD anywhere. `f6-kenken` is the sole creator of the `puzzle-board`
and `puzzle-content` capabilities, so the six board changes below report *"target spec does not
exist"* only because kenken aborted first — but each of them also carries its own orphan header,
so with kenken landed they would fail with `- not found` instead.

| Change | What it needs |
|---|---|
| `f2-shell-and-preferences` | `app-shell/req-shell-draws-the-bar`, plus three orphan MODIFIEDs under `home` |
| `f6-kenken` | `home/req-home-offers-the-puzzle`, `pack-builder/req-builder-carries-puzzles` |
| `f3-router` | creates `api-routing` *and* MODIFIES `req-openapi-declares-405` in it |
| `ci-pg-client-install-is-bounded` | creates `ci` *and* MODIFIES `req-a-matching-pg-dump` in it |
| `f6-killer`, `f6-magic-square`, `f6-kakuro`, `f6-word-search`, `fix-selected-cell-is-invisible`, `fix-cage-outline-is-the-boards-weight` | `puzzle-board` / `puzzle-content` from kenken, then their own orphan headers — `req-board-cage-label`, `req-board-pad-offers-what-fits`, `req-board-domain-is-declared`, `req-board-margin-targets`, `req-board-run-clues`, `req-puzzle-words-must-be-present`, `req-the-selected-cell-is-visible`, `req-weight-belongs-to-the-object` |

**What unblocks them is a decision, not a sweep.** Each orphan header is either a requirement that
should have been ADDed by the change that first drew the thing, or a MODIFIED block that should
have been an ADDED one. Deciding which is a specification call: guessing writes an invented
requirement id into `openspec/specs/`, which is worse than a capability being absent.

The cost of leaving them: `puzzle-board`, `api-routing` and `ci` have no capability under
`openspec/specs/` at all, so `openspec show puzzle-board` returns nothing for five board formats
that are shipped and playable.

Recorded 2026-08-26, after the archive sweep. Delete this file when the ten are archived.
