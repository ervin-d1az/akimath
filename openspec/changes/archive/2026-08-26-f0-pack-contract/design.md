## Context

See `proposal.md` — Why. What shapes the approach, and is not restated there:

- `packages/contract` does not exist. `packages/server` is the only TypeScript package on disk and
  it installs with **npm and its own `package-lock.json`** — `pnpm-workspace.yaml` declares a
  workspace and a `catalog:`, but pnpm is not installed on this machine and the root scripts do not
  run (`CLAUDE.md`, Commands).
- `ARCHITECTURE.md` §2 forbids response polymorphism — *"no `oneOf`, no `discriminator`; variance
  lives inside an opaque `params`/`payload`"* — and §1 lists the offline pack format and
  `canon.golden.json` + `CHAR_MAP` among the six things that must stay in lockstep across the two
  stacks. §6 makes the boundary *"a directory of pinned, versioned artifacts, not a handoff."*
- `ARCHITECTURE.md` §4's invariant governs what the pack may contain: *"The prompt travels
  rendered. The answer never travels online. Offline, a membership verifier travels and its verdict
  is provisional until sync."* Its `offline_packs` table gives the pack a `pack_salt` and an
  `expires_at`.
- Two decisions arrive already taken and are inputs, not options: **Q2** (2026-08-15) — per
  labelled distractor `HMAC(canonical answer) → { misconception, steps, explain }` plus one generic
  non-scolding fallback per skill — and **§7.0 B** — the pack declares skill-map node state.
- The consumer that does not exist yet is the one the format is for: `f1b-content-reader` writes a
  Dart parser and must compare it against something this change commits.

## Goals / Non-Goals

**Goals**

- Freeze a format that survives a late answer to a content question by leaving reserved, versioned,
  nullable slots rather than by leaving fields out.
- Make the TypeScript↔Dart seam checkable by data rather than by review: every kind fixtured, every
  rejection row fixtured, every normalisation recorded.
- Keep every decision provable without a filesystem, a clock or a seed (PURE-1), so the one adapter
  in the package is a script that writes bytes.

**Non-Goals** (design-level; the scope list is in `proposal.md` — Non-goals)

- No abstraction over "where a pack comes from". This change defines bytes and their meaning; the
  reader, the downloader and the builder are three later changes and none of them needs an
  interface declared here.
- No performance target. A pack is a handful of items and five 6×6 boards.
- No shared runtime between the stacks. The parity mechanism is a committed fixture, not a
  generated Dart file — `f1b-content-reader` hand-writes its parser and the fixture catches drift.

## Decisions

### D1 · The prompt is `{ kind, payload }`, and `ARCHITECTURE.md`:179 is corrected

`ARCHITECTURE.md`:179 types the response prompt as `PromptToken[]`. A 3×3 matrix with margin
arrows, a function machine, seven elastic tiles, two pair-cards joined by a bridge pill, and
figurate figures whose dot radius shrinks with the count are not a flat token list.

**Chosen:** `kind` is the closed six-member enum of the plan's §3.4 sealed `Stimulus`
(`arithmetic`, `numberSeries`, `matrix`, `analogy`, `hiddenOperation`, `figurate`), and `payload`
is an opaque per-kind object with one schema each.

**Alternatives rejected.** *Keep `PromptToken[]` and encode structure in the token stream* — the
renderer would have to re-derive a grid from a sequence, which is exactly the parsing-by-convention
that drifts across a language seam. *A discriminated union in the emitted schema* — banned outright
by `ARCHITECTURE.md` §2 for the OpenAPI half, and having the pack disagree with the API on this
would mean two shapes to keep in lockstep instead of one. The opaque payload is what §2 permits,
and the price it charges — six hand-written parsers on each side — is paid by the fixtures.

### D2 · `AnswerSpec` and `PuzzleSpec` are closed unions with the same discipline

`AnswerSpec` is `(num, den)` for a fraction and an integer for the other five families.
`PuzzleSpec` is keyed by `PuzzleKind { kenken, kakuro, killer, magicSquare, wordSearch }` with an
opaque per-kind payload. Same shape as D1, same reason, same mitigation.

The pack carries puzzles at all because `f6-puzzles` promises *"plays fully offline"* while
`CLAUDE.md` forbids generating a board on the client — so boards, blocked cells, cages, targets,
solutions, tutorial steps and reference-sheet content must arrive in the pack, and the format
freezes here, three phases before that change is written. **Alternative rejected:** defer the
puzzle half to F6. That reopens a frozen artifact, which is the one thing this change exists to
prevent.

### D3 · The diagnosis payload is a reserved, versioned, nullable slot

Q2 is answered, but the mechanism that made the format survivable while it was open stays: the item
carries `diagnosis: DiagnosisPayload | null`, separately versioned from the pack. Filling it is
`f1-5-pack-builder`'s job; a pack that carries `null` is valid today.

Inside it, per labelled distractor: `digest → { misconception, steps, explain }`, plus one generic
fallback per skill. **The correct answer is never in the pack in plaintext** — `ARCHITECTURE.md`
§4's *"the answer never travels online"* and its membership-verifier posture. Q2 records the cost
of getting this wrong: a readable `explain` blob per distractor makes the correct answer *the one
not in the list*, so the distractor keys are digests and the fallback is what an unmatched answer
resolves to.

`explain` and the fallback copy are **es-MX**; LANG-1's split puts player-facing text in Spanish and
everything else in English, and these strings are read by a child on `04 Error`.

### D4 · The digest is `HMAC-SHA-256(pack_salt, canonical answer)`, keyed per pack

The message construction has to freeze with the format: it is one of `ARCHITECTURE.md` §1's six
cross-stack contracts, and `CLAUDE.md` names HMAC message construction as ours to write while
authentication crypto is not.

**Chosen:** the key is the pack's `pack_salt` (already a column in `ARCHITECTURE.md`:197), the
message is the UTF-8 bytes of the canonical answer and nothing else, the output is lowercase hex,
untruncated. **Alternatives rejected.** *A per-item salt* — the data model pays for it and the pack
already scopes a salt. *Including the item id in the message* — it makes the digest unforgeable
across items, but it also makes the Dart side reproduce a composite message, which is one more
thing to get wrong at the seam for a threat model where the whole pack is on the device anyway.
*Truncating the digest* — saves bytes and invents a collision question nobody has to answer.

`node:crypto.createHmac` is deterministic and reads no clock, no environment and no entropy source,
so it does not breach PURE-1. The restriction `ARCHITECTURE.md` §3 names is `crypto.randomUUID`,
which is randomness; this is not.

### D5 · Canonicalization runs in one direction, and the pack's stored answers are already canonical

This reconciles what looks like a contradiction between the rejection rows and the keypad. The
answer draft's `neg` key produces a **leading U+2212** (plan §3.4), yet U+2212 is listed among the
rows a fixture must be rejected for.

**Chosen:** two distinct obligations over one function.

- `canonicalize(raw) → CanonicalAnswer | RejectionTag` is what the client applies to *learner
  input*. `CHAR_MAP` folds the characters a keypad or a keyboard can legitimately produce —
  U+2212 among them — into the canonical form.
- The **pack validator** requires every stored canonical answer to already be canonical:
  `canonicalize(stored) == stored`, with no folding needed and no rejection raised. A pack carrying
  `""`, `"1/0"`, `"x+1"`, U+0660, a raw U+2212, ZWSP or a combining mark in an answer field is
  **malformed**, which is exactly what the spec's rejection-row scenario asserts — it parses a
  *fixture*, and a fixture is pack content, not a keystroke.

Row by row, so BUILD does not have to guess which of the two obligations each one exercises:

| Row | Learner input | Stored in a pack |
|---|---|---|
| `""` | rejected, `empty` | rejected, `empty` |
| `"1/0"` | rejected, `zero_denominator` | rejected, `zero_denominator` |
| `"x+1"` | rejected, `non_numeric` | rejected, `non_numeric` |
| U+0660 Arabic-Indic zero | rejected, `non_ascii_digit` | rejected, `non_ascii_digit` |
| U+2212 minus sign | **folded** by `CHAR_MAP` to ASCII `-` | rejected, `not_canonical` |
| ZWSP U+200B | rejected, `invisible_character` | rejected, `invisible_character` |
| combining mark | rejected, `combining_mark` | rejected, `combining_mark` |

U+2212 is the only row that differs, and it differs because the keypad produces it: the `neg` key
toggles a leading U+2212 (plan §3.4). Folding it is what lets the child's answer reach the same
bytes the pack was built against; rejecting it in stored content is what stops two spellings of the
same answer from producing two different digests. ZWSP and the combining mark are **rejected rather
than stripped** — silently deleting an invisible character from an answer is how a wrong answer
becomes a right one.

That is also what makes the digests in D4 well-defined: both stacks digest the same bytes because
both reach the same canonical form first. **Alternative rejected:** let the pack carry whatever the
author typed and canonicalize at read time. Then the digest depends on when canonicalization ran,
and the drift R2 names becomes invisible instead of impossible.

`contract/fixtures/canon.golden.json` is **emitted from the code**, not hand-written —
`ARCHITECTURE.md` §3 records what a hand-written golden vector cost when the canonical snippet
turned out not to produce the vector that was claimed. Its job is cross-stack parity, and the Dart
run at `f1b-content-reader` is what checks it.

### D6 · The emitted artifact set includes the recorded normalisation of every fixture

`f1b-content-reader`'s `req-pack-parity` reads: *"the normalised structure equals the TypeScript
parser's recorded output for that fixture."* If this change commits only the fixtures, that
sentence has no referent and F1b has to invent one — which puts the comparison back on the change
that depends on this one, i.e. the cycle the plan broke on purpose.

**Chosen:** the emitter writes, next to each fixture, the structure the TypeScript parser
normalises it to, and the determinism gate covers those records as well. This is the added scenario
under `req-pack-artifact`; it is not in §4's code fence and is derived from F1b's requirement.

### D7 · Wire spelling: snake_case fields, lowerCamelCase enum values, fixture filenames verbatim

Three conventions collide here, so it is decided once rather than per file.

- **Field names are snake_case.** `ladder_step`, `expires_at`, `pack_salt` are already written that
  way in `ARCHITECTURE.md`:194-198 and throughout the plan. The API response shapes stay camelCase
  (`itemId`) exactly as `ARCHITECTURE.md`:179 writes them — a pack is a data artifact, a response
  is an API, and neither is renamed to match the other.
- **Enum values are lowerCamelCase**, identical to the sealed-type member names on both sides:
  `numberSeries`, `hiddenOperation`, `magicSquare`, `wordSearch`. A wire value that differs from
  the identifier needs a mapping table in two languages, which is a drift surface for no gain.
- **A fixture's filename is its wire value verbatim.** `contract/fixtures/stimulus/numberSeries.*`,
  `contract/fixtures/puzzle/magicSquare.*`. The eleven-kinds scenario enumerates the directory and
  compares it to the enum; making that a string equality with no transformation is the point.

**Why `otp` is in the enum with no consumer here.** §5.3 D14 ties it to `1.3 Verificar correo`, an
F3 screen, and this change's Non-goals exclude auth outright. The enum still closes at three now:
reopening a frozen enum is exactly what this change exists to prevent, and D14 already did the
counting that says there is no fourth. Its consumer arrives at `f3-auth-screens`; until then `otp`
is a value the format accepts and no fixture uses.

### D8 · Zod, pinned exactly, and the DEP-1 audit

`CLAUDE.md`'s planned layout already commits `packages/contract` to *"Zod + OpenAPI emitter"*, and
`f1-contract-emitter` will need Zod there regardless. **DEP-1 audit:** Zod is an in-process schema
library — no network call, no environment read, no telemetry, nothing collected. It is the first
runtime dependency in the repository (`packages/server` has no `dependencies` key at all), so the
audit is stated in the PR as DEP-1 requires.

**Pin it to an exact version, not a caret.** A `^` range plus a byte-determinism gate means an
unrelated `npm ci` months later re-emits different bytes and turns CI red with no diff in the
repository — the failure mode that gets a determinism gate deleted rather than fixed. This design
does **not** name the emitting API: the constraint is one dependency and byte-identical output
across two runs, and BUILD picks the call that satisfies it.

### D9 · Which side of the PURE boundary each new module sits on

`openspec/config.yaml` requires this per module. The split copies
`packages/server/src/routing.ts` versus `packages/server/src/adapters/http-server.ts`.

| Module | Side | Why |
|---|---|---|
| `src/pack.ts` — root schema, format version | **PURE-1** | a shape, proved by parsing a literal |
| `src/canon.ts` — `CHAR_MAP`, canonicalization, rejection tags | **PURE-1** | a string function; this is the module R2 names as the drift site |
| `src/digest.ts` — the HMAC message construction (D4) | **PURE-1** | deterministic over given bytes; no clock, no entropy |
| `src/stimulus/*.ts` — six payload schemas | **PURE-1** | six shapes |
| `src/answer.ts` — `AnswerSpec` | **PURE-1** | a closed union |
| `src/puzzle/*.ts` — five payload schemas, cage coverage, sum feasibility, uniqueness | **PURE-1** | a solver over a board literal is a decision, not IO; it needs no mock |
| `src/keypad-layout.ts` — the three-member enum | **PURE-1** | an enum |
| `src/diagnosis.ts` — payload schema and digest lookup | **PURE-1** | a map lookup over given data |
| `src/skill-map.ts` — node state schema | **PURE-1** | a shape |
| `src/index.ts` — the package's public surface | **PURE-1** | re-exports only |
| `src/adapters/emit.ts` — writes `contract/**` | **PURE-2** | the only module that touches the filesystem, and it holds no decision: it serialises what the pure modules produce |

Stryker's `mutate` narrows to `src/` **excluding `src/adapters/`**, mirroring
`packages/server`'s exclusion of `main.ts` and `adapters/`.

### D10 · The uniqueness check is exhaustive, and bounded by an explicit node budget

*"A board with no unique solution is rejected"* implies a solver. **Alternative rejected:** trust
the author and check only cage coverage and sum feasibility. That ships a puzzle a child cannot
finish, offline, with no way to report it.

**This decision first read "§5.3 D15 caps the board at 6×6, so an exhaustive constraint search over
a 36-cell board with cages is milliseconds". That was false, and it was measured false** on boards
`BoardSchema` already accepts, with the modules as written:

| Board | Unbounded search |
|---|---|
| magic square 5×5, 12 printed cells | `solution_not_unique` in 474 ms |
| magic square 5×5, 4 printed cells | `solution_not_unique` in 12 325 ms |
| magic square 5×5, 3 printed cells | `solution_not_unique` in 96 599 ms |
| kakuro 5×5, one unsatisfiable column | `solution_mismatch` in 6 303 ms |
| *control* kenken 6×6 | `solution_not_unique` in 0 ms |

D15 bounds the **board**, not the **search**. KenKen and Killer are cheap because `latinRegions`
gives every row and column a `distinct` rule over a domain of `size` digits. The other two kinds
have neither half of that: `magic-square.ts` draws from `digitsUpTo(size * size)` — 36 values on a
6×6 — under a single global `distinct`, and `kakuro.ts` draws from `digitsUpTo(9)` with no Latin
rule at all. Partial pruning also bites weakly down columns, because `fillableCells` walks the
board row-major and no column region completes before the last row.

**Chosen:** `search` in `uniqueness.ts` takes a `SearchBounds { solutionLimit, nodeBudget }` and
returns a `SearchOutcome` that is either `counted` or `budgetExhausted`, carrying the value trials
it spent either way. `SEARCH_NODE_BUDGET` is **500 000**, measured rather than guessed: the
costliest 6×6 board this change accepts is the kakuro fixture at 34 308 trials, so the budget
carries about fifteen times the worst legitimate cost, and every board in the table above now
returns in **under 310 ms**. A board that outruns it is rejected `search_budget_exhausted` — a new
member of `PuzzleRejectionTag`, following the discipline `parsePack` already has: nothing throws
and every rejection names itself. An unaffordable board becomes a verdict its author reads, not a
build that appears to hang.

The budget only bites while the verdict is still open. `search` checks the solution limit before
the node budget, so a second solution already in hand is never downgraded to "unknown", and the
budget can only ever turn an acceptance into a rejection — the fail-closed direction. The rows in
the table above therefore change tag as well as time: an unbounded search that reached
`solution_not_unique` after 96 seconds now reports `search_budget_exhausted` in 304 ms. Both are
rejections, so no board that was refused is now shipped.

**Alternatives rejected.** *A wall-clock deadline* — it reads a clock, which breaks PURE-1 and
makes the verdict depend on the machine. *A cheaper search (MRV ordering, arc consistency,
column-first cell order)* — it would raise the ceiling, but a faster search with no bound is still
unbounded, and the failure mode this fixes is the absence of a verdict, not its cost. Recorded as
an accepted trade-off rather than done here. *Leaving the budget to each caller* — the budget is a
decision, so it lives in the pure module Stryker mutates, not in five call sites that could drift.

**The affordability claim is now tested at the ceiling.** Every puzzle assertion in this change ran
at 3×3 while `BoardSchema` allows `size` up to 6, so the claim was untested exactly where it
fails. `test/fixtures.test.ts` now carries one `size: 6` board per puzzle kind — a KenKen whose
eighteen cages add, subtract and multiply, a Killer of eighteen sums, a Kakuro whose runs break on
an interior wall, a magic square over thirty-six numbers, and a 6×6 word search — each accepted,
together with the same magic square left twelve cells blank, which is reported
`search_budget_exhausted`. They are test literals rather than files under `contract/fixtures/`
deliberately: `goldenStems` and the emitter's `goldenNames` both admit only `<stem>.json`, so a
second board per kind committed there would be read by nothing.

### D11 · The `contract` CI job is emit + `git diff --exit-code`, and nothing else yet

`ARCHITECTURE.md` §8 job 4 is *"emit + `git diff --exit-code` + `oasdiff` breaking-change check"*.
The `oasdiff` half needs `contract/openapi.json`, which `f1-contract-emitter` produces. This change
adds the job with the first two steps, wires it into `gate`'s `needs`, and says in the job's own
comment which step is missing and which change adds it — the same honesty the existing header
already applies to `protected-paths`, `compliance`, `integration` and `mutation`.

`.github/workflows/ci.yml`'s `ts` job has `working-directory: packages/server` and caches on that
package's lockfile, so the new package needs its own job rather than a line in that one.

### D12 · Four documents name the command set, so all four move in one change

PROC-5 says outright that *"the rulebook, the hook and CI must name one set of commands; if they
ever diverge, reconcile them in the same session (PROC-6)"*, and PROC-7 says a convention that
reaches planning lives in `openspec/config.yaml` as well. Adding a second TypeScript package
diverges four files at once:

- `.claude/hooks/verify-gate.sh` — its filter fires on any `packages/` path but it only runs
  `packages/server`, so a contract-only change would be gated by nothing.
- `.github/workflows/ci.yml` — the `ts` filter, the new job, `gate`'s `needs`, and the header
  comment that lists `contract` under *"Not implemented yet, deliberately"*.
- `CLAUDE.md` — the Commands block and "What exists today".
- `openspec/config.yaml` — its `context:` block tells every future proposal that
  `packages/contract` does not exist.

**Alternative rejected:** land the package now and reconcile later. Later is a session where nobody
remembers which of the four is authoritative.

### D13 · Test filenames follow the plan; source filenames follow the disk

The plan's scenarios name `pack_format.test.ts`, `fixtures.test.ts`, `canon.test.ts`,
`keypad_layout.test.ts` — snake_case — and those names are the acceptance criteria, so they are
binding. `packages/server` writes sources in kebab-case (`http-server.ts`). Sources here follow the
disk, tests follow the plan, and the mismatch is recorded rather than silently resolved in either
direction.

## Risks / Trade-offs

- **The format freezes with two consumers unwritten.** → Every extension point is a reserved,
  versioned, nullable slot (D3), and the eleven fixtures are what a later change edits against.
- **Six hand-written parsers per side (D1) have no compiler help across the seam** — R2b. → One
  golden fixture per kind plus recorded normalisations (D6); a kind that lands at
  `f2-stimulus-families` with no fixture is R2b's stated early signal.
- **A green fixture suite that would stay green with the canonicalizer inverted is not evidence** —
  R2 is precisely this module. → Tier 1b is not optional here: `npm run mutation` (Stryker) and
  `npm run dry` (jscpd) on `packages/contract`, with the scores produced in that session.
- **Byte determinism is a gate that fails for reasons outside the diff.** → The exact pin in D8, and
  `contract/` emitted by one script rather than by several call sites.
- **A second npm package widens the pnpm gap.** `pnpm-workspace.yaml`'s `catalog:` already
  disagrees with `packages/server`'s pinned `typescript@^5.7.2`; a third pin makes the eventual
  migration bigger. → Accepted, and named: the new package pins the same TypeScript
  `packages/server` uses today, so the migration stays one change rather than two shapes.
- **`contract/` is exactly the kind of path `ARCHITECTURE.md` §7 wants a `protected-paths` job in
  front of, and that job does not exist.** → Out of scope here (proposal, Non-goals), and worth
  Ervin's attention: this change creates the first artifact whose silent edit by an agent would be
  invisible to CI beyond the determinism gate.

## Migration Plan

Nothing to migrate: no consumer, no stored data, no deployed surface. Rollback is deleting
`packages/contract/`, `contract/`, and the four reconciliations in D12 — the last of which is the
only part that touches a file another change depends on.
