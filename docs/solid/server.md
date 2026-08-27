# SOLID audit — `packages/server/src/`

Audited at `653a17b` on `main`, read-only, 2026-08-27. Scope: `routing.ts`, the eight implemented
operations, `adapters/`, the retention job and the CLI wiring.

## Verdict

This module is in good shape, and unusually so: the pure/IO split is real rather than aspirational,
the route surface is held to the emitted contract in both directions by a gate that also tests its
own detector, the dependency graph has no back-edges, and the two "only these files may do X"
invariants are among the best patterns in this repository. The single most expensive thing in it is
that **`adapters/http-server.ts` has quietly become the package's second policy module**: eight
handlers' worth of orchestration plus four decision-carrying helpers now live in the one file that
`stryker.config.json` excludes from mutation, `vitest.config.ts` excludes from coverage, and whose
tests all sit behind `describeWithDatabase`. Two of those helpers are already pure functions that
would run under both gates unchanged if they sat in `rating.ts` and `packs.ts`. Everything the
package built its evidence culture around — mutation, coverage, a suite that runs without a
Postgres — stops precisely where its most intricate code starts.

The second most expensive thing is not a code-structure defect at all: `offline_packs.content_id`
names shipped content by a **mutable name**, so editing the artifact that name resolves to silently
re-points every outstanding pack, and the resulting wrong verdicts land in an append-only table.

Seven findings below, cost-ordered. Twelve further candidates were discarded (see Coverage).

---

## Findings

### 1 — PURE-2: the request path's decisions have drifted into the socket adapter, which is the one place three gates cannot see

**Principle.** PURE-2 ("the adapter that performs the IO holds no decisions — it translates and
nothing else"), with Ousterhout's *change amplification* as the cost.

**Where.**

- `packages/server/src/adapters/http-server.ts:381` — `landedRows`, a pure function: rows, a step
  map and a landed set in, `RatedAttempt[]` out. It encodes the decision that *only what the
  `ON CONFLICT DO NOTHING` insert actually wrote may move a rating*.
- `packages/server/src/adapters/http-server.ts:516` — `stepInContent`, a pure function encoding
  three distinct "this server cannot say how hard that was" cases as `null` rather than a default.
- `packages/server/src/adapters/http-server.ts:405` — `applyRating`, which needs the client, but
  whose `wanted` construction (dedupe of `(skillId, ladderStep)` pairs through `difficultyKey`) is
  a decision, not a translation.
- `packages/server/src/adapters/http-server.ts:466` — `gradingSourceFor`, which needs the client,
  and which decides that a digest entry's ladder step comes from the *content the row names*.
- `packages/server/src/adapters/http-server.ts:131` — the `ISSUED_CONTENT = "starter"` constant,
  whose own comment calls choosing between packs "a product decision".

**Cost.** `stryker.config.json:9` excludes `src/adapters/**` from mutation; `vitest.config.ts:20`
excludes it from coverage; and every test that exercises these paths — `submit-attempts.test.ts:43`,
`rating-loop.test.ts:29`, `issue-pack.test.ts:19` — opens with `describeWithDatabase`, which is
`describe.skip` when `TEST_DATABASE_URL` is unset (`test/support/database.ts:22`). So this code has
no mutation evidence, no coverage measurement, and does not execute at all on a developer machine
without a Postgres — while `npm run verify` reports green. CI's `postgres:18` container does run
the tests, and that is the honest mitigation; mutation and coverage never do, at any time, by
configuration. A newcomer changing the rating's "only what landed" rule cannot discover that the
rule has no falsification behind it, because every signal the package trained them to read
(a mutation score, a coverage report) is silent about that file by design.

**The canon disagrees here, and the disagreement decides the remedy.** Martin reads an adapter
holding decisions as a class to split; Ousterhout reads chopping a working function into pieces as
making the module *shallower*, and calls that a defect. Both are right about different halves of
this file. Side with Martin on `landedRows` and `stepInContent`: they are already separate functions
with exactly those signatures, so relocating them adds no interface surface and creates no new
abstraction — it is a move, not the chop Ousterhout warns about. Side with Ousterhout on
`applyRating` and `gradingSourceFor`: leave the functions whole. Breaking a client-holding
orchestrator into pieces buys call sites and nothing else.

**Direction.** Surgical, not a chop: `landedRows` and `stepInContent` are already pure and would
move to `rating.ts` and `packs.ts` *unchanged*, where both gates already reach — the seam is that
neither touches `client`. From `applyRating` and `gradingSourceFor` move only the decision (the
`wanted` dedupe; the null-rather-than-default rule), not the function. `ISSUED_CONTENT` belongs wherever the next content decision will be made,
which its own comment says is rating's, i.e. F4's.

### 2 — `content_id` names content that can change under an already-issued pack, and the wrong verdict it produces is unrepairable

**Principle.** Not a SOLID letter — this is *unknown unknowns* in Ousterhout's sense: you cannot
tell, from anywhere in either package, what else you must change when you edit an authored item.

**Where.** `packages/server/src/adapters/pack-repository.ts:28` stores `contentId` as `text`
(`migrations/0006_an_issued_pack_may_name_its_content.sql:35`), written as the literal `"starter"`
from `src/adapters/shipped-packs.ts:31`. `getOfflinePack` rebuilds the pack body from
*today's* artifact (`src/adapters/http-server.ts:274`), while grading reads the manifest digest
recorded **at issuance** (`src/adapters/attempt-repository.ts:101`), and the rating's ladder step
comes from today's artifact again (`src/adapters/http-server.ts:524`).

**Cost.** Adding a *new* shipped pack is safe. Editing or reordering items inside the existing
`packages/core/pack/starter.json` — a normal content act, and `npm run build:pack` exists to make
it easy — silently re-points every outstanding pack: within the 30-day window
(`src/packs.ts:29`) a device that re-fetches gets today's item at index *i*, verifies it offline
against today's digest, answers correctly, and the server compares that answer to the digest of the
*old* item at index *i*. The result is `ok: false` recorded in `attempts`, which the request path
holds no UPDATE and no DELETE grant on; the rating then moves against whatever ladder step today's
item carries. Nothing warns, and the test that looks like it covers this does not:
`test/issue-pack.test.ts` issues and re-fetches inside one run, so it can only ever see agreement
within a single version of the artifact. Re-fetch is not an edge case: the device stores the pack id
and nothing else, so `GET /packs/{packId}` is the routine relaunch path.

**This is also the answer to "is the pack and its manifest kept in order by the types?"** Within
one process, no — but by something stronger than adjacency: `src/packs.ts:124` derives the manifest
with a single `.map` over `checked.pack.items`, so equal length and equal order are structural for
that call. The type does not carry it (`IssuedPack` at `src/packs.ts:31` is exported and any caller
can construct a mismatched pair), but there is one writer and it cannot get it wrong. The alignment
that *is* unenforced is the one across the issuance/re-fetch boundary, where the two sides derive
from artifacts that can differ — which is this finding.

**Direction.** `content_id` records a name; have it record a name *and a digest of the artifact*.
`getOfflinePack` already has the branch this lands on — the `content === undefined` case at
`src/adapters/http-server.ts:277` answers 404 for content the build no longer ships, and content
whose bytes no longer match is the same fact.

### 3 — the "only these files may do X" pattern is the right pattern, and two things it should cover are outside it

**Principle.** ISP at the component level, and PROC-10's "a gate whose input list silently reaches
zero" applied one step out: a gate whose *subject* list silently omits a member.

**Where, and the more expensive half first.** `packages/server/src/adapters/request-database.ts:45`
exposes `asOwner` on the production `RequestDatabase` interface. It runs work as the connecting
role — the login role that **owns the schema** — with no transaction and no `SET LOCAL ROLE`. It
has zero callers under `src/` (its own doc comment says so, and it is true: the only uses are
`test/request-database.test.ts:54,163`). `test/one-way-to-erase.test.ts:70` names the two files
allowed to say `inErasureRole`, and `:90` pins `DELETE FROM` to `player-repository.ts`. Neither
assertion moves if `http-server.ts` calls
`database.asOwner((client) => deletePlayerForAccount(client, id))`: `inErasureRole` still appears in
exactly two files, `DELETE FROM` still appears in exactly one. The invariant CLAUDE.md calls
structural — *the request path holds no DELETE* — has a second, unnamed door on the same interface,
and that door is strictly more powerful than the sanctioned one, because the owner holds DELETE on
every table rather than on the ones `retention_job` was granted.

**The second half.** `test/policy-holds-no-io.test.ts:24` names its **subjects**: the scan at
`:125` iterates `POLICY`, so a new `src/whatever.ts` importing `pg` is not caught — the only
reverse check (`:114`) asks whether each *named* module exists, which catches a typo and not an
omission. The comment at `:19` justifies this with `one-way-to-log.test.ts`'s reasoning, but the two
mechanisms are inverted: `one-way-to-log.test.ts` scans **everything** and names one *exception*,
which scales; naming the subjects means the next policy file is unguarded until someone remembers.
CLAUDE.md's architecture rule states the contrast itself for the Dart side — *"The root is a glob,
not a list, so `design/math/spec/` was covered the moment it existed and no one had to declare it"*.
Today the list is complete (16 named, `main.ts` the only other top-level file), so this costs
nothing yet and will cost exactly one silent gap the day it does.

**Direction.** For `asOwner`: it exists to let one test observe that a role did not leak, which is a
reason to build it in the test support from the same connection string rather than to publish it on
the interface every handler holds — or, at minimum, to name it in `one-way-to-erase.test.ts`
alongside `inErasureRole`. For `POLICY`: keep the named list as the *report*, and add the missing
direction — every top-level `src/*.ts` is either in `POLICY` or excused by name.

### 4 — a public operation is unrepresentable, and that is a closed model that is correct today rather than a missing variant

**Principle.** OCP, judged by what the next variant costs.

**The call.** Closed and correct, with two costs — not a defect to fix now. The discriminating fact
is the contract: `contract/openapi.json:1136` declares `security` once at the root and **no
operation overrides it**, so every one of the nine contracted operations does require a session,
and `route()` answering 401 to `caller.kind === "absent"` for every entry of `ALL_ROUTES`
(`src/routing.ts:219`) is the model refusing a case that does not exist. `Decision`'s non-optional
`userId` (`src/routing.ts:66`) is the same statement made in the type, and it is worth keeping:
it is what makes "a handler cannot forget whose request this is" true by construction. This
repository's own rule — rules and structures describe code that exists — argues against adding a
variant for a caller nobody has.

**The two costs, so the next author is not surprised by them.**

- The one route that *is* public is handled by a literal string comparison above the table
  (`src/routing.ts:208`), and appears in `OPS_ROUTES` only so a wrong method earns a 405. A second
  public route therefore means editing `route()`'s body, not the table — the table is closed to
  extension for exactly the property the table exists to describe.
- No gate would notice the disagreement. `test/support/contract.ts:157` already implements
  OpenAPI's `security: []` override correctly, so the harness can *read* a public operation, while
  `test/contract-parity.test.ts:148` only checks the secured ⇒ 401 direction for contracted
  operations. The reverse direction is checked only for `OPS_ROUTES`
  (`test/contract-parity.test.ts:160`). A public operation added to the contract would pass every
  gate in the package and answer 401 in production.

**Direction.** Nothing today. When it lands, the seam is a field on `Route` (which is where the
surface already lives, and is inside the parity gate's reach) plus the missing gate direction —
*an operation the contract does not secure must not answer 401* — which costs one `filter` beside
the one at `test/contract-parity.test.ts:148`.

### 5 — LSP: one arm of `GradingSource` returns where its sibling throws, and the caller cannot tell

**Principle.** LSP, in the sealed-pair form: a subtype usable where the supertype is, without the
caller knowing.

**Where.** `src/attempts.ts:372`, `gradeSource`. The `digest` arm is total — an answer the
canonicalizer refuses is *wrong*, not an error (`src/attempts.ts:398`). The `template` arm calls
`rederive` and `resolve` (`src/attempts.ts:315,382`), and the module's own doc at `:306` states
that an unresolvable reference throws on purpose. The single call site
(`src/adapters/http-server.ts:197`) passes whichever arm the repository produced and has no way to
distinguish them.

**Cost.** A throw becomes `run()`'s 500 (`src/adapters/http-server.ts:652`) for the **whole batch**,
and the client reads 500 as `SyncFailed`, which `app/lib/features/sync/policy/attempt_journal.dart:165`
maps to *not landed* — so the batch is kept and resent on every launch, for ever, in a journal
capped at what one batch can carry. One retired template version turns into a permanently stuck
sync for every device holding an attempt against it. Ranked below findings 1–3 because it is
**near-unreachable today**: nothing writes `issued_items`, every issued pack is a copy whose every
manifest entry is a digest, so the template arm has no live producer. It becomes reachable the day
`GET /items/next` or a template-generated pack lands.

**Direction.** The seam already exists and is one branch wide: `gradingSourceFor`
(`src/adapters/http-server.ts:466`) already answers `null` for a source this player does not have,
and `null` already becomes the 404 at `src/attempts.ts:433` that the Dart client treats as a batch
to drop. A reference the registry cannot resolve is the same class of fact — the server cannot grade
it, and no retry will change that.

### 6 — WIRE-1: a Dart policy's correctness argument rests on the branch order of two `if`s in `link.ts`, and nothing on this side records that

**Principle.** WIRE-1, and CCP read across a package boundary: two things that must change together
live where neither author can see the other.

**Where.** `src/link.ts:101` and `:107` return two different `why` strings; `conflictResponse`
(`:114`) sends both as the tag `already_linked`. The client recovers the distinction with a
`GET /me` probe whose exactness argument, written out at
`app/lib/features/states/policy/account_state.dart:190`, is literally *"`linkOutcome` tests
`playerForAccount !== null` before `accountForPlayer !== null`"*.

**Cost.** Modest, and stated precisely because the strong version is not true: swapping the two
branches changes the player-visible story in essentially no case, since when only one condition
holds the inference survives either order, and when both hold `GET /me` answers 200 either way. The
real cost is that a server author refactoring `linkOutcome` has **no signal at all** that a Dart
policy's stated exactness depends on the order — the one test covering the overlap
(`test/link.test.ts:168`) asserts only `kind`, not `why`. WIRE-1 itself notes the cheaper remedy is
available and measured: `ErrorSchema.error` is `z.string()`, so a distinct tag changes no schema and
leaves `contract/openapi.json` byte-identical.

**Direction.** Either make the ordering non-load-bearing by giving the second refusal its own tag,
or make it visible here: `test/link.test.ts:168` is one assertion away from pinning the precedence
with the reason attached.

### 7 — two doc comments have detached from what they describe

**Principle.** CMT-2, in its mildest form: a comment sitting above a declaration it is not about.

**Where.** `src/adapters/http-server.ts:60-69` describes `Handlers` (declared at `:87`) and sits
immediately above `HandlerRequest`. `src/adapters/http-server.ts:611-617` describes `run`
(declared at `:632`) and sits immediately above `readJsonBody`.

**Cost.** Small and specific: tooling attaches the *nearest* preceding block, so both orphans are
invisible on hover and both real declarations show nothing. The two pieces of rationale that
disappear are the ones a reader most needs at those names — why the handler map holds no routing,
and why a handler's exception message must never reach the client.

---

## What this module gets right, and why

**Gates that test their own detector.** This is the pattern worth copying out of this package, and
it is rare anywhere. `test/one-way-to-erase.test.ts:73`, *"the prose is stripped before the scan,
and the stripping works"*, fires `codeOf` at four inputs including one that must still match —
because the gate reads for `DELETE FROM` and the code it scans *explains* the DELETE invariant in
prose, and a rule that fires on its own explanation gets switched off.
`test/policy-holds-no-io.test.ts:137` fires its forbidden-import patterns at a real adapter to prove
they match real code rather than nothing. `test/contract-parity.test.ts:210` is the control for a
gate that reads a list: every id in `IMPLEMENTED_OPERATIONS` really does reach a dispatch, and no
other operation does. `test/every-built-operation-has-a-handler.test.ts:50` checks the values are
functions, because comparing key names would pass for a key whose value is not one. Four separate
authors of four separate gates each asked "what would make this green for the wrong reason", and
answered it in the file.

**The router owns the surface, and the reason is written down where the trade was made.** Declining
Hono's router (`src/adapters/http-server.ts:530`) costs a catch-all handler and buys a route table
that `contract-parity.test.ts` can read; the same trade is refused a second time by keeping
`Handlers` keyed on the contract's `operationId` rather than letting the map route itself
(`src/routing.ts:54`). Both comments name the gate rather than claiming one in the abstract, which
is CMT-3 obeyed rather than cited.

**ADP: verified, not reasoned about.** Every `../` import from `src/adapters/**` points at a policy
module; nothing under `src/*.ts` imports an adapter; `cli/` imports adapters and nothing imports
`cli/`. Zero back-edges, so either half is testable alone — which is exactly what
`test/routing.test.ts` and `test/http-server.test.ts` do.

**Component direction points at stability.** `@akimath/core` and `@akimath/contract` are pure, have
their own determinism and import-boundary gates, and depend on nothing here. `packages/core`
declares `@akimath/contract` as a *dev* dependency and that is correct rather than sloppy: the
contract-importing files are the pack builder and the puzzle batcher, which `index.ts` does not
reach, and `packages/core/test/import_boundary.test.ts` is what keeps it so. The Dart/TypeScript
canonicalisation fork is deliberate, reasoned and held by `contract/fixtures/canon.golden.json`; it
is the opposite of a DRY defect, because the two copies are prevented from changing independently.

**A refusal that is a real state.** `history.ts:76`'s `roundedDelta` distinguishes *"we did not
measure you"* from *"we measured you and you held"* by refusing to render `0` for the first, and
`standing.ts:38` refuses to invent a 404 for a player nobody has rated. Both are WIRE-1's "the state
that claims the least is a real state" applied without being asked to.

**`log.ts` redacts values, not field names.** `src/log.ts:110` is the reason a token cannot reach a
log line even when somebody interpolates one into a message, and the connection-string case keeps
the host on purpose — a redactor that blanks the whole value teaches people to log around it.

**Comments carry rationale a name cannot.** `session.ts:37` records that a branch was *deleted*
because mutation testing showed it unreachable, and why. `rating.ts:173` records that a comparison
was removed because both spellings were equivalent mutants. `retention.ts:48` records why 400 days
is absolute elapsed time and cites the Dart bug that proved the calendar reading wrong. None of
these is a name that could have said the same thing.

---

## Coverage

**Read in full.** `CLAUDE.md`, `.claude/conventions/craftsmanship.md`; 16 of the 17 top-level
modules of `packages/server/src/` — every one but `migrate.ts`, which is out of scope — plus
`src/cli/retention.ts`; and eight of the thirteen adapters: `http-server.ts`, `request-database.ts`,
`retention-job.ts`, `logger.ts`, `pack-repository.ts`, `shipped-packs.ts`, `attempt-repository.ts`
and `rating-repository.ts`, which are the ones every finding runs through. Of the tests: `routing.test.ts` in part, `contract-parity.test.ts`, `every-built-operation-has-a-handler.test.ts`,
`one-way-to-log.test.ts`, `one-way-to-erase.test.ts`, `policy-holds-no-io.test.ts`,
`retention.test.ts`, `link.test.ts`, `http-server.test.ts` (names only), `support/contract.ts`,
`support/database.ts`. Outside the package: `contract/openapi.json`'s security block,
`packages/core/package.json` and `src/index.ts`, `app/lib/api/api_client.dart`'s sync reader,
`app/lib/features/sync/policy/attempt_journal.dart`, `app/lib/features/states/policy/account_state.dart`.

**Checked and found clean.** The import graph for cycles (mechanically, per file — zero back-edges).
The pure/IO boundary for the 16 named policy modules — none imports `pg`, an adapter or `node:`.
`routing.ts`'s status ladder against the contract's declared statuses, both directions and per
operation. `IMPLEMENTED_OPERATIONS` against the handler map, both directions. The retention figures'
single home, including the excuse list and its "an excused file really is an HTTP file" control.
`packages/core`'s contract dependency being genuinely dev-only. The Dart/TypeScript canonicalisation
fork, which is deliberate and gated.

**Read for imports and signatures only, not line by line.** `session-verifier.ts`,
`player-repository.ts`, `history-repository.ts`, `standing-repository.ts` — enough to place them in
the dependency graph and to know what they hand the pure layer, not enough to audit their SQL. A
reader extending this audit should start there.

**Could not judge.** Runtime behaviour of anything behind `describeWithDatabase`: **the 129
database-backed tests did not run in this session** — no Postgres was started and none was
provisioned — so every claim above about handler behaviour is from reading the code and its SQL, not
from execution. No mutation run and no coverage run was performed here, so no score is quoted as
evidence (PROC-5). **The migration runner was not opened at all** — `src/migrate.ts`,
`src/adapters/migrate-runner.ts` and `src/cli/migrate.ts` are outside this audit's scope (routing,
the eight operations, the adapters, the retention job) and nothing here should be read as a
judgement on them; only `migrations/0006` was read, for finding 2. Whether Hono's
`context.json` accepts every status in `ContentfulStatus` was not exercised.

**Discarded: twelve candidates**, as taste, as already-gated, or as costing nothing I could state.
Named, so the next reader does not re-derive them: the Dart/TypeScript canonicalisation duplication
(deliberate, reasoned, golden-held); the exhaustive `switch` on `LinkOutcome.kind`; the length and
nesting of the `submitAttempts` handler; the `playerIdForAccount` → `noPlayerResponse` prologue
repeated across five handlers (omitting it does not compile, so it is not a hazard); the
`difficultyKey`/`classOf` string round-trip (justified by `Map` key identity, both ends in one
module); the `ContentfulStatus` cast; `PORT` and `APP_VERSION` being read inline in `main.ts:10-11`
while the other two environment reads are pure and validated (a bad `PORT` throws
`ERR_SOCKET_BAD_PORT` at startup, verified — it fails loudly, so the inconsistency costs an operator
a stack trace instead of a named variable, and nothing more); the five-counter `RetentionRun`
growing by one field per swept table; `retention.test.ts` excusing `http-server.ts` from the
bare-`400` sweep; `insertPack`'s `skill_nodes[0]!`; `rateAttempts` returning `unplaced` and
`calibrating` that no operator can see yet (declared deliberately deferred at `rating.ts:57`); and
the `Response` type living in `routing.ts` and being imported by every policy module, which is
`import type` and therefore erased at runtime.
