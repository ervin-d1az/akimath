# AkiMath

Adaptive math challenges in Mexican Spanish, with a dog called Aki. Flutter client,
TypeScript backend, Postgres on Neon (planned). One repository — see
[ARCHITECTURE.md](ARCHITECTURE.md) §1 for why.

**The audience is adults, and children can play too** (Mexico and Spanish-speaking LatAm,
decision #1; clarified 2026-08-17). Read both halves — the product is not child-directed and its
register should not be, but a **mixed audience is governed by its youngest member**, so every
protection an under-13 needs is unconditional: no third-party SDK that collects data, no ads, no
external analytics.

That distinction is doing work rather than decorating. It is why `players.age_band` exists and is
resolved before the device obtains any session: the band is the **routing decision** that sends a
player into child protections or not, not a compliance residual. And it is why Gate A's question is
"what does a general-audience app owing child protections have to do", not "what does a
child-directed app have to do" — a materially different question with a different answer.

Where a comment or a document says "a child", ask whether it means *the player* or specifically
*the under-13 case*. Much of the prose written before this clarification says the first and means
the second. Before adding *any* dependency, check whether it phones
home; if it does, it does not go in. Today that constraint holds by construction — `app/`
ships `flutter`, `cupertino_icons`, `meta` and `shared_preferences` at runtime — the last
added 2026-08-16 with its audit recorded in `dependency_allowlist_test.dart` itself — `packages/server` has no
`dependencies` key at all, and `packages/contract` has exactly one: `zod`, pinned to an
exact `4.4.3` because the pack determinism gate is byte-for-byte.

**Code, identifiers, comments and docs are in English.** Only end-user-visible text is in
es-MX.

## Layout

```
app/                      the Flutter client — the only Dart package
  lib/api/                 the hand-written API client (ADR 0001). `dart:io`, no dependency
  lib/design/brand/spec/   pure geometry: no Canvas, no widgets, testable without mocks
  lib/design/brand/        the adapter that paints that spec
  lib/design/tokens/       colors, type, shape. No color literal lives outside tokens/
  lib/features/            screens
  test/architecture/       import-graph and literal gates: pure predicates + one SourceTree adapter
packages/server/          @akimath/server — pure `routing.ts`, IO in `adapters/`
packages/contract/        @akimath/contract — the offline pack format, pure; emitter in `adapters/`
packages/core/            @akimath/core — the rederivation machine. ZERO runtime dependencies,
                          no ambient IO; the one adapter writes the golden artifacts
contract/                 the frozen artifacts: 3 schemas, 37 fixtures, canon.golden.json,
                          openapi.json (OpenAPI 3.0.3, emitted, byte-diffed and oasdiff'd)
docs/adr/                 ADR 0001 decides the Dart API client; older decisions live in ARCHITECTURE.md
```

`app/lib/api/` now exists and holds one operation. `packages/contract` holds the offline pack
format and its OpenAPI half.

## What exists today

- **Built and tested — and playable.** `main.dart` opens the round: an item renders, the keypad
  takes an answer, a verdict comes back. On top of the brand layer sit the math compositor
  (`design/math/`), the press primitives, the dashed outline, the verdict encoding, the keypad,
  and `features/round/` with its three pure policies, plus the stat readouts — tiles, both pill
  sizes, the counter chip and the baseline meter — and the two verdict screens, `03 Acierto` and
  `04 Error`, which show time and streak and **no rating**: F2 has no server, so nothing on them is
  a figure sync could later contradict. `features/shell/` is the frame: cream, a banner slot, and a
  **bottom bar with three roots** — `Inicio`, `Avance` and `Ajustes`. `visibleTabs` returns nothing
  while one root exists, so the bar was absent by rule rather than by omission; it appeared when
  preferences did and grew when `Avance` landed, both times without the policy being touched.
  **`features/progress/` is `Avance`**, and it has two halves that fail independently: the figures
  the device knows — days practised, the current run, moved out of Ajustes because what a player
  has done is not a setting — and the history the server knows, from `GET /me/history`. **The
  `HISTORIAL` section is absent when there is nothing true to say** — no account, or no sessions —
  because nothing in the app sends an attempt yet, so a heading there would stay empty however much
  a player played and the line under it would be a promise the product cannot keep. Same reading as
  the toggles Ajustes does not draw (DR-P2). The three states somebody has to act on do get the
  section, and a banner; a refused session gets no retry, because asking twice with a dead token
  gets the same refusal. **No rating and no accuracy**: both are F4
  and `ratingDelta` comes back null, and a screen printing `±0` would be inventing a figure. The
  session that makes any of it possible is held by `RootScaffold` — two roots have to agree about
  whether there is an account, and their common ancestor is the only place that can hold it. In
  memory only; `LinkedSession.toString` does not carry the token, because `toString` reaches logs
  and crash reports. The app opens on **`FirstRunGate`**, which reads one
  boolean and shows either the first run — `0.2 Bienvenida`, then `0.3 Primer reto`, a fixed teaching
  item that reads no pack, records no day and shows no streak — or the **home**: Aki, the
  `RETO DEL DÍA` preview composed by the real compositor, the week strip, and
  `ROMPECABEZAS` — **one card per puzzle the pack carries**, named by the pure `puzzleMenu`. A series is pushed from
  there as a full-screen route with no navigation affordance. The first run completes when the item is
  **solved**; leaving it, by the close control or a system back, returns to the welcome and sets
  nothing. The streak is **earned within a session** — `DayLog` records
  the day on submit and the home re-reads it — and is persisted by `shared_preferences`.
  **Verified on a device across two launches of two different binaries** (2026-08-17): a build with
  no write code read a day the previous build had written, with the key confirmed on disk. CocoaPods
  is required for the iOS build — `pod` must be installed or `flutter run` cannot link the plugin. **1697 Flutter tests, green — among them `app/lib/api/`, which is
  checked against `contract/openapi.json` by `test/api/contract_parity_test.dart` the way the
  server's half is.**
  **Ajustes has a way out.** `features/preferences/` carries the erasure flow: a text door under
  the account, drawn only where `erasureOffered` says a session could carry the request, and a
  full screen rather than a dialog because the question has to fit a sentence about what
  *survives* — the address stays registered with the identity provider, which is not ours to
  delete. `policy/erasure.dart` is pure and holds the copy; `ui/erase_account_route.dart` takes
  the request as a **closure** rather than an `ApiClient`, which is what lets a `testWidgets`
  drive the whole sequence — a real socket inside a fake-async zone hangs on `!timersPending`.
  A 204 is read as a success **without parsing a body**: a client that reads it the way it reads
  `GET /me` turns an erasure into a `FormatException`, and that is the one error here a retry
  cannot fix, because the row is already gone.
  **`api/sync.dart` can ask for a pack and send back what was answered** — `issuePack` and
  `submitAttempts`, the two halves of the offline loop from the device's side. An
  `AttemptSubmission` refuses on the device to name neither source or both, because a 400 a player
  waits for is worse than a batch that never leaves; it carries **no verdict**, because the frozen
  schema has nowhere to put one; and `elapsedMs` travels, because the server cannot derive time on
  task — a pack item has no `issued_at` of its own. The four failures are told apart by what a
  client should *do*: a 400 is a batch to drop, a 404 is a batch that landed nowhere, and
  unreachable is the one worth keeping, because the server drops a duplicate by itself (0004).
  Nothing calls either yet, and the reason is one step further back: **nothing in the app calls
  `linkPlayer`**, so an account is made and no player is ever attached to it — which is why the
  account section draws `noPlayer` and why `POST /packs` and `GET /me/history` would both answer
  404 for a real player today. Linking is the next change; the pieces waiting on it are
  `features/sync/`, which remembers an answered pack item until the server has it. That journal is
  persisted rather than held in memory, because play is offline and sync is not: a player answers
  on a bus and the batch goes days and several launches later. It keeps at most what one batch can
  carry — the server refuses more than two hundred, so a longer journal could never be flushed —
  and what survives a failed sync is decided in one place: a batch that landed is gone, a batch the
  server could not read is **dropped** because resending a malformed one resends it for ever, and a
  refused session or no answer at all is **kept**, which is what the journal is for.
  **All six frozen stimulus families draw and grade** — arithmetic, number series, matrix,
  analogy, the function machine and figurate. `content/model/stimulus_reader.dart` holds the six
  hand-written parsers and `test/content/model/stimulus_fixture_test.dart` checks each against
  `contract/fixtures/stimulus/`, one golden and one rejection row per kind, reporting
  *6 frozen kinds → 6 readable, 0 pending*. That is R2's remedy moved from grading to layout, and
  it is what makes adding a family mechanical. Four of them share `StimulusTile`; figurate paints
  dots from `design/math/spec/figurate_layout.dart`, the one file excluded from
  `no_geometry_literal_test` and excluded by name rather than by directory.
  Content is a **bundled 70-item JSON pack** (`app/assets/packs/starter.json`) read by
  `content/pack_reader.dart` — the one adapter in `content/`. An expired or malformed pack is
  refused where it is read. **Its order is a product decision under test**: `seriesPlan` takes five
  items in pack order, so `pack_variety_test.dart` holds the pack to showing all six families
  inside the first ten items and no more than two of a kind in any series. **Grading answers to the frozen contract**: `content/model/canon.dart` is
  checked against `contract/fixtures/canon.golden.json` itself, 19 vectors in both modes, which is
  what stops the Dart and TypeScript canonicalisers drifting (R2).
  **All five frozen puzzle formats draw and grade** — KenKen, Killer, the magic square, Kakuro
  and the sopa de letras. `content/model/puzzle_reader.dart` parses them and
  `test/content/model/puzzle_fixture_test.dart` reports *5 frozen kinds → 5 readable, 0 pending*,
  with one exception named rather than hidden: Kakuro's `solution_not_unique` is the builder's,
  because only a solver can see it. Four share `PuzzleScreen` — a board, a keypad sized by
  `PuzzleBoard.highestValue`, and the pure entry policy; the sopa de letras has its own screen
  because it has no keypad, and its drag is resolved by `letterAt` rather than by a detector per
  cell. **Every one of them is reachable**: `home_route_test.dart` walks the shipped pack, opens
  each puzzle from the home and comes back, reporting *5 shipped → 5 kinds reachable*. That gate
  exists because the home once held `pack.puzzles.first` behind an `is! KenKenPuzzle` guard, and
  four of the five formats were unreachable with every suite green.
- **A scaffold, plus the frozen schema.** `packages/server` routes one endpoint, `GET /health`,
  through a pure `route()` function, and now also holds the database:
  `migrations/0001_initial.sql` (seven tables, two roles, and the grants that make `attempts`
  append-only) plus five forward-only ALTERs, the forward-only runner split pure/adapter as `src/migrate.ts` versus
  `src/adapters/migrate-runner.ts`, `src/retention.ts` (PURE — the only home of the 400-day and
  30-day figures) and the committed `schema.sql` snapshot. **360 tests, green, 98.92% mutation
  score, 0 clones.** Four runtime dependencies, each pinned exactly with its DEP-1 audit in
  `test/dependency-allowlist.test.ts`: `pg`, `hono` + `@hono/node-server` (which own the socket —
  Hono's *router* is deliberately unused, so `CONTRACTED_OPERATIONS` stays where the parity gate
  can read it), and `jose`.
  **It can tell who is asking.** `src/session.ts` reads the `Authorization` header (PURE, three
  cases — absent, malformed, bearer), `src/auth-config.ts` derives the issuer and JWKS URL from
  `NEON_AUTH_BASE_URL` (PURE; a missing or plaintext one **refuses startup** rather than turning
  into a 401 per request), and `src/adapters/session-verifier.ts` verifies the EdDSA JWT against a
  key set that is *injected*, so the tests run the real function against real Ed25519 keys.
  **`NEON_AUTH_BASE_URL` is not set anywhere yet** — it lives on the Neon console's Auth page and
  is not derivable from the connection string, so `npm run dev` exits 1 until somebody pastes it in.
  **Seven endpoints are implemented.** Three are the account's whole life — `GET /me` reads the
  profile, `POST /players/link` creates it, `DELETE /me` erases it — three are the offline loop,
  `POST /packs` issuing, `GET /packs/{packId}` fetching again and `POST /attempts` grading, and
  `GET /me/history` reads back what the loop wrote. Each verifies the
  token and connects through `src/adapters/request-database.ts`, which opens a transaction and
  `SET LOCAL ROLE`s into a role that is never the owner. `GET /me` answers the frozen `Me` shape,
  or **404 and not 401** when the account has no player yet. `POST /players/link` takes the
  account from the *session* and refuses a body that so much as names one; it runs both reads and
  the write in one transaction, so a race loses to a **409** rather than to a constraint.
  `route()` returns *an answer* or *whose handler should produce one*, so the surface stays where
  the parity gate reads it, and `IMPLEMENTED_OPERATIONS` is the contract's 501 list inverted,
  checked in both directions — an endpoint stops advertising itself as unbuilt in the same diff
  that builds it. The other two — `GET /items/next` and `GET /me/standing` — still answer **501**.
  **Erasure is the one handler that does not run as `app_request`.** That role holds DELETE on no
  table, which is what makes the append-only-attempts invariant structural; `DELETE /me` goes
  through `inErasureRole` (`SET LOCAL ROLE retention_job`) and deletes one `players` row, and the
  five tables that reference it go with it by `ON DELETE CASCADE` — `test/delete-me.test.ts`
  counts the rows in every one rather than trusting the schema to still say so, and
  `template_stats` survives by design because it carries no player id. The hole is kept to one:
  `test/one-way-to-erase.test.ts` names the only two files under `src/` allowed to say
  `inErasureRole`, the same shape as `one-way-to-log.test.ts`.
  **An authored item is graded by its digest, which is the only way it can be.** Rederivation
  needs a template reference and an authored item has none — so `(pack_id, pack_index)` could not
  address one and nothing could grade it, which meant *the pack the app actually ships could never
  be synced*: seventy of its eighty items are authored. Migration 0005 renames `template_refs` to
  **`item_refs`**, because it now holds two kinds — `{kind: "template", …}` to rederive and
  `{kind: "digest", digest, skill_id}` to verify — one per item and in the same order, which is
  what makes `(pack_id, index)` address anything. `packages/core`'s `manifest.ts` is the one
  definition of both. Verifying is `HMAC(pack_salt, canonicalize(what was typed))` against what the
  pack already carries, through the same two functions the pack builder used, so **the server never
  learns an authored answer** — it holds a digest and can only confirm or deny a guess, which is a
  stronger position than rederivation leaves it in. A pack of authored items is re-fetched by
  rebuilding the content the row names (migration 0006); a pack that carried digests and named no
  content could not be rebuilt, and nothing writes that combination.
  **`POST /attempts` grades by rederiving, and that is the invariant made true by construction.**
  A submission carries no `ok` — `readAttemptBatch` refuses a body that mentions one, along with
  every other unknown property — so the server resolves the recorded
  `(template_id, template_version, seed, ladder_step)`, regenerates the item and compares canonical
  spellings. Both halves of "canonical" come from `packages/contract`, the package Dart is
  golden-tested against, because a third implementation here is exactly R2. `@akimath/core` and
  `@akimath/contract` are therefore the package's first **first-party** runtime dependencies, kept
  in their own list in `test/dependency-allowlist.test.ts`: DEP-1 exists to summon a human about
  third-party code that phones home, a workspace link has no version to pin, and an unsatisfiable
  rule gets deleted. They are held to `file:../<name>` and to bringing nothing unaudited — today
  `zod`, and the test says so.
  An attempt names **exactly one source**, mirroring `attempts_one_source`, and a batch is one
  transaction: every source is resolved before anything is written, so an unknown item is a 404
  naming its index with nothing recorded. **A retry is harmless**, decided 2026-08-19 and made so
  by migration 0004: an item is answered **once**, two partial unique indexes say so, and the
  insert is `ON CONFLICT DO NOTHING` — the verdicts are recomputed from the same inputs, so the
  second answer is the first, idempotent by nature the way `linkPlayer` is. A batch naming the
  same item twice is refused before any of it is read, because keeping one of two rows and
  answering as if both landed is worse than saying so. The constraint is the thing to argue with
  if replaying a series ever becomes a feature, which is the right place for that argument.
  0004 also persists **`session_id`**, which every submission has carried since the freeze with
  nowhere to land — it is what a `GET /me/history` entry is grouped by.
  **`POST /packs` is the ninth operation, added because there were only eight.**
  `GET /packs/{packId}` fetched a pack by an id and nothing minted one, so `offline_packs` could
  only ever be empty and a pack attempt could never reach `POST /attempts`. Issuing takes no body —
  the player comes from the session — and no `Idempotency-Key`, because issuing is not idempotent
  by nature and a second pack is harmless. **Every item is template-generated**, and that is a
  constraint rather than a simplification: an authored item carries no template reference, so
  `(packId, index)` could not address it and nothing could grade it. `src/packs.ts` builds the pack
  and its manifest *together and in the same order* — one list seen from the two ends of the
  offline loop — and `test/issue-pack.test.ts` closes it for real: issue, rederive the answer from
  the row the server wrote, sync it, and watch it come back `ok: true`. **What is issued is a copy of the pack the app
  already ships** — eighty items across six families and thirty-five boards. Migration 0006 adds
  `content_id`: the row *names* the content rather than storing it, because the artifact is 158 KB
  and it is the same 158 KB for every player, which is `ARCHITECTURE.md` §4's manifest argument one
  level up. `GET /packs/{packId}` rebuilds from that name plus the row's own window, so a re-fetch
  is byte-identical and neither instant is digested. A copy shares the content's salt, and that is
  not a leak: the salt ships inside every pack and every player gets the same content. The
  generator that made twenty subtractions is **gone** — after 0005 both kinds were equally
  gradeable, only one was worth playing, and code nothing calls is a claim about the server that is
  not true. `storedAnswer` lives in
  `packages/contract` so the pack builder and the server make one decision about shape and
  spelling — that is the bug from #50 and a second copy is how it returns.
  **`GET /me/history` is a session at a time.** The frozen shape asks for a `score` and a `title`
  and neither means anything about one answered item. `ratingDelta` is **null** because rating is
  F4 and a number would be invented; `kind` is always `series`, because a puzzle leaves no row in
  any table so nothing can report one. A session spanning two skills is **not** named after
  either — `min(skill_id)` would call it whichever sorts first, which is not a fact about the
  session. `@akimath/core`'s `skillName()` is where a skill gets a name, since `skill_id` is a
  `smallint` in five tables and a name in none of them. The operation declares no parameters, so
  `HISTORY_LIMIT` is the server's cap and it is stated in `src/history.ts` rather than buried in
  the query.
  **The retention job sweeps what issuance leaves.** `runRetention` used to delete `diag_events`
  and `attempts` and keep every pack for ever; issuance turned that from theoretical into live. It
  now sweeps `offline_packs` past their window and `issued_items` too — last, and behind a
  `NOT EXISTS`, because both are referenced with `ON DELETE CASCADE` and deleting one early would
  take a child's answered history with it. `RETENTION_DAYS.sources` is keyed on when a source
  *stopped being usable*, so a pack outlives every attempt that could reference it by arithmetic,
  and the guard makes it true by construction. **`GET /packs/{packId}` rebuilds rather than
  reads a body back** — `offline_packs` stores a manifest and a salt, not fifty rows of rendered
  item, which is what the manifest is *for*. Every digest comes back identical, because the salt
  is a column and the answers rederive; `test/issue-pack.test.ts` issues a pack and asserts the
  re-fetch equals it exactly. The one thing that can differ is prose — the fallback diagnosis is
  copy and copy gets edited — and prose is in no digest. A pack belonging to somebody else is the
  same **404** as one that never existed, because telling them apart confirms a stranger's pack
  exists. **A path parameter is the router's to extract**: `route()` returns them named on the
  dispatch, so a handler never splits a path it did not match. **It does not delete the Neon Auth
  account** — identity lives in the provider's `neon_auth` schema and this service holds no
  credential that could remove it, so the email and the sign-in survive the call. That scope is
  written into the operation's `description` in `contract/openapi.json` rather than left for a
  caller to infer from a 204. A `204` is rendered by `context.body(null, 204)` and never by
  `context.json`, which throws on a null-body status; `NoContent` is a separate type from
  `Response` so a 204 carrying a body does not compile.
  **There is one way to write a log line.** `src/log.ts` (PURE) turns an event into one JSON
  object — `at`, `level`, `msg`, fields at the top level — and `src/adapters/logger.ts` is the
  **only** file under `src/` allowed to touch a stream, which `test/one-way-to-log.test.ts`
  enforces by scanning for `console.*` and `process.stdout` and reporting a count. **The logger
  cannot print a credential**: redaction runs over *values* as well as field names, at any depth
  and inside `msg` itself, so a JWT, a `Bearer …` header or the password in a connection string is
  replaced wherever it appears — the host and database survive, because that is usually why the
  line was written. Every request leaves one line carrying the **kind** of caller and never the
  caller. `pino` was audited and turned down: 14 transitive packages against this package's floor
  of zero, and path-based redaction that protects the fields you thought of.
  `packages/core`'s three build scripts keep `console.log` on purpose — their output is a developer
  watching `npm run emit`, not a log. The Flutter side needs nothing: `avoid_print` is active via
  `flutter_lints` and `app/lib` has zero prints **by rule**.
  **The database suites need a Postgres and skip without one** — set `TEST_DATABASE_URL` and they
  run; leave it unset and 102 of the 360 report as skipped rather than passing quietly.
- **The offline pack format, frozen.** `packages/contract` (`@akimath/contract`) holds the
  pack schema, the answer canonicalizer, the HMAC digest and the puzzle validators — all
  pure, with the emit script as the one adapter. `contract/` holds what it emits: the
  schemas, one golden fixture and one rejection row per stimulus and puzzle kind, their
  recorded normalisations, and `canon.golden.json`. 189 tests, green, 91.71% mutation score,
  0 clones. **Zod 4.4.3 is the repository's first runtime dependency**, pinned exactly
  because the determinism gate is byte-for-byte.
- **Does not exist.** Two of the nine contracted endpoints — `GET /items/next`, which needs an
  issuance policy, and `GET /me/standing`, which needs a rating — no dev environment, no deploy, and
  no deployed *application*. **The database is provisioned**: a Neon project (`akimath`,
  `aws-us-east-1`, PostgreSQL 18.4) with both migrations applied, its connection strings in
  `packages/server/.env.local`, which is gitignored. `MIGRATE_DATABASE_URL` is the direct string and
  `DATABASE_URL` the pooled one; **`TEST_DATABASE_URL` is deliberately not set there**, because the
  harness drops and recreates the public schema on every run. **The pack builder is written**: `packages/core`'s
  `src/pack/` lifts authored items and template-generated ones into one pack, and
  `npm run build:pack` emits `packages/core/pack/starter.json` — 80 items across six families and
  5 puzzles, byte-identical on a second run, which is what makes the CI diff mean something.
  **Every generated item in it used to be ungradeable** and is not any more: the answer's *shape*
  and the *spelling* the digest was taken over were computed separately, so a whole answer of −9
  was digested as `-9/1` while the field beside it said `integer` — and `canonicalize("-9")` is
  `-9`. The same mismatch disabled the guard that drops a distractor equal to the right answer,
  so one item shipped a `subtracted_in_reverse` diagnosis whose digest *was* its own answer.
  Latent only because the app ships the authored pack. Both now come from one `shape`.
  Item generation beyond the one template family is still unwritten. **A template declares which
  skill it exercises** (`Template.skillId`), because `attempts.skill_id` is `NOT NULL` and nothing
  on the wire carries it — an attempt names an item, an item is a `TemplateRef`, and neither
  `issued_items` nor `offline_packs.template_refs` records a skill. The pack declaration used to
  state it a second time next to a template source and now **refuses** to: two places stating one
  fact is one place that can be wrong, and the wrong one would be the pack's. The rederivation
  machine is on the package's front door — `registryOf`, `resolve`, `rederive`, `issuable` and
  `coreRegistry()`, the last a *call* because every export is a function and a registry is a `Map`
  behind an interface. **The diagnosis copy is a value**, not `content/misconceptions.json`, which
  is deleted: `packages/server` issues packs inside a request and needs the same words, and reading
  another package's content directory from a request path is ambient IO in the one package that
  forbids it. `misconceptionCopy()` and `fallbackDiagnosis()` are the front door; the prose lives in
  `src/pack/misconception-copy.ts` and is the one file excluded from mutation testing, because every
  mutant there blanks a Spanish sentence and the only test that could kill one would restate it.
  It is parsed **on first use and not at module load**, which is not a style choice: a
  module-scope parse turns a bad edit into an import failure, every file importing it dies before
  its assertions run, and Stryker scores those mutants as survived. `misconceptions.ts` read
  56.31 that way and 93.27 once the parse was deferred, with the same tests. **`toManifestEntry`/`fromManifestEntry` are there too**: how a
  `TemplateRef` is written into `offline_packs.template_refs` and read back is one definition
  now, shared by the builder that will write it and the server that already reads it. It used
  to be a reader matching a comment in ARCHITECTURE, and a mismatch would have made
  `refForPackItem` return null for every real pack — a 404 indistinguishable from a missing row. **The math compositor is
  built**: `EsMxNumber`, `FractionMetrics`, `MathNode` (pure) and `MathView` + `FractionGlyph`
  (adapters) are landed and tested. Spike B cleared its criterion on 2026-08-16 — see
  `openspec/changes/f1b-math-compositor/spike-b/`.
- **CI exists, narrowed to the code that exists.** `.github/workflows/ci.yml` runs `changes`,
  `secrets` (gitleaks), `dart` (`flutter analyze --fatal-infos`, `flutter test`), `ts`
  (`npm run typecheck`, `npm test` in `packages/server`), `contract` (the same two in
  `packages/contract`, then `npm run emit`, `git add -A -- contract/` and
  `git diff --cached --exit-code -- contract/` — staged, because a bare `git diff` is blind to
  an artifact the author never committed), `spec` and `gate`.
  `protected-paths` and `integration` landed with the schema: the first refuses an unattended edit
  to `packages/server/migrations/**` or `schema.sql` unless a pull request carries the
  `allow-protected-edit` label, and the second runs the database suites and the snapshot diff
  against a **`postgres:18` service container** rather than ARCHITECTURE.md §8's ephemeral Neon
  branch — a container needs no account, no project and no secret, and what those tests assert is
  plain PostgreSQL behaviour. ARCHITECTURE.md §8's remaining jobs — compliance, mutation — are
  deliberately absent because the code they guard does not exist; `contract` now runs its `oasdiff`
  half too, version-pinned, failing only on a **breaking** change — a gate that fires on every
  addition trains people to switch it off — and that break can be **answered** rather than only
  obeyed: an `allow-breaking-contract` label on the pull request passes it, the same shape as
  `allow-protected-edit`, because before v1 ships a breaking change is ordinary and a gate with no
  way to say yes gets deleted instead. `gate` is registered on the `protect-main` ruleset, so **CI blocks a merge into `main`**. Its
  checks report a few seconds after a push and `gh pr merge` refuses until they do, with *"the base
  branch policy prohibits the merge"* — which reads like a permissions problem and is a timing
  one.
- **The workspace is declared but not live.** The root `package.json` names
  `pnpm@11.21.0` and `pnpm-workspace.yaml` carries a `catalog:`, but pnpm is not installed
  and `packages/server` still pins its own `typescript@^5.7.2` against the catalog's
  `^6.0.3`. **The root scripts do not run.** Use the per-stack commands below.

Work is tracked by the phase vocabulary in ARCHITECTURE.md §9 (`F0`…`F8`). There is no
ticket tracker. F0 through F2 are done and **F6's five puzzle formats are all playable**; the
server side is still at the scaffold, so the next phase with code behind it is **F3**.

## Commands

```sh
# Flutter — from app/
flutter analyze --fatal-infos
flutter test

# Tier 2, on a booted simulator. **`flutter test` does not reach
# `integration_test/`**, which is how three of these suites sat broken for
# weeks against copy that had changed under them. Run them when a screen or a
# flow moves. Five suites, six cases: the playthrough, the shell's three roots,
# every board format opened from the home, the press travel measured in the
# shipping build, and the account tour, which skips itself without endpoints.
#   xcrun simctl list devices booted        # take the id
#   flutter test integration_test -d <id>
#   # the account tour needs the endpoints, and skips itself without them:
#   flutter test integration_test -d <id> \
#     --dart-define=NEON_AUTH_BASE_URL=... --dart-define=AKIMATH_API_BASE_URL=...

# Running it on a simulator against a real backend. **Both steps matter.**
#   `--dart-define` is baked into `kernel_blob.bin` at build time, and a build
#   that reuses a cached kernel silently keeps the old values — so the app comes
#   up with `Endpoints.configured` false and the account row simply absent, with
#   nothing on screen to say why. And `simctl install` over an existing bundle
#   does not reliably replace `App.framework`, so uninstall first.
#   Verify rather than trust: the URL must appear in the *installed* blob.
#     rm -rf build/ios/iphonesimulator .dart_tool/flutter_build
#     flutter build ios --simulator --debug \
#       --dart-define=NEON_AUTH_BASE_URL=... --dart-define=AKIMATH_API_BASE_URL=...
#     xcrun simctl uninstall booted com.akimath.akimathApp
#     xcrun simctl install   booted build/ios/iphonesimulator/Runner.app
#     xcrun simctl launch    booted com.akimath.akimathApp
#   The uninstall takes `shared_preferences` with it, so every run of this
#   starts at `0.2 Bienvenida` again — the bottom bar lives on the home, which
#   is two taps past the first run.

# TypeScript — from packages/server/
npm run verify        # tsc --noEmit && vitest run
npm run mutation      # Stryker over src/, excluding main.ts, adapters/ and cli/
npm run dry           # jscpd duplication
npm run migrate       # apply migrations; needs MIGRATE_DATABASE_URL (the DIRECT string)
npm run schema:dump   # regenerate schema.sql; the tree must not move afterwards
npm run retention     # delete expired rows; needs RETENTION_DATABASE_URL

# A database to run the above against, local:
#   brew install postgresql@18 && brew services start postgresql@18
#   (18, because that is what Neon provisioned and CI mirrors production;
#    `pg_dump` output is byte-identical on 17 and 18, verified)
#   createdb akimath_dev
#   export TEST_DATABASE_URL=postgresql://localhost/akimath_dev

# TypeScript — from packages/core/
npm run verify        # tsc --noEmit && vitest run
npm run mutation      # Stryker over src/, excluding adapters/ and index.ts
npm run dry           # jscpd duplication (src/templates/** is excused — see its README)
npm run emit          # rewrite golden/; the tree must not move afterwards
npm run build:pack    # rebuild pack/starter.json from content/ and the authored asset

# TypeScript — from packages/contract/
npm run verify        # tsc --noEmit && vitest run
npm run mutation      # Stryker over src/, excluding adapters/
npm run dry           # jscpd duplication
npm run emit          # rewrite contract/; the tree must not move afterwards
```

`flutter analyze --fatal-infos` + `flutter test` + `npm run verify` **in all three TypeScript
packages** are the everyday gate, and
they are the *enforced* gate: `.claude/hooks/verify-gate.sh` runs them on every `git commit`
and `git push` and exits 2 (blocking) on a failure, and `.github/workflows/ci.yml` runs the
same commands — both spell the TypeScript half as `npm run typecheck` then `npm test`, which is
what `npm run verify` chains. Run `--fatal-infos` locally or the hook will surprise you.
Mutation and jscpd are the deeper pass (tier 1b below), run when the logic under change is
worth them.

One tool is installed and is **not a command here**: `dart run mutation_test` has no rules XML,
so it is green by construction and is not evidence. The Dart substitute for mutation is the
falsification step in the rulebook's PROC-5.

The metrics tool **is** configured now, and CI runs it:

```sh
# Flutter — from app/, and part of the `dart` CI job
dart run dart_code_linter:metrics analyze lib --set-exit-on-violation-level=warning
```

`--set-exit-on-violation-level` is not optional decoration. Measured: without it — and even with
`--fatal-warnings` — the command prints its warnings and exits **0**, which is the same
green-by-construction trap one level deeper. The thresholds in `analysis_options.yaml` are set at
what the code does today, so the next function past one is a decision somebody makes on purpose;
they ratchet down as the code gets simpler and never up to accommodate it.

## Workflow

TDD, clean code and clean architecture are requirements here, not preferences. Red → green →
refactor; the test is seen failing first. One small, logical commit per coherent change.

Planning runs on [OpenSpec](https://openspec.dev). A unit of work is a **change**, its id is the
change name, and its plan is committed to `openspec/changes/<change-id>/` rather than left in a
scratch directory — so the plan a reviewer reads later is the plan that was approved.

| Phase | One line | Owner |
|---|---|---|
| SPEC | `/opsx:explore` to think, `/opsx:propose` to write. Output is `proposal.md`, `design.md`, `tasks.md` and delta specs whose `#### Scenario:` blocks are the acceptance criteria. **Human approves the proposal before any code.** | main session |
| BUILD | Implement one task from `tasks.md`, test-first, against those scenarios. | `craftsman-engineer` |
| REVIEW | Conventions pass over the diff, citing rule IDs. | `craftsman-reviewer` |
| BUG HUNT | High-severity correctness only, each finding with a concrete trigger. | `craftsman-bug-hunter` |
| EVIDENCE | State the tier reached. | see below |
| LAND | Commit and push only when asked. | main session |
| ARCHIVE | `/opsx:archive`, only after the pull request has merged. | main session |

There is no DEPLOY phase: there is nothing to deploy to.

`/opsx:propose` will not touch project code — the approval gate is enforced by the tool, not by an
agent's restraint. Read the plan back with `openspec show "<change-id>"` and check the gate with
`openspec status --change "<change-id>" --json`; both read disk, which is the point. Project-wide
conventions reach every proposal through `openspec/config.yaml`, so edit that file rather than
repeating the rules in each one.

**Evidence tiers.** Three names, used identically in this file, in the rulebook and in every
agent — if you find a fourth numbering somewhere, that file is wrong.

- **Tier 1 — the committed suite.** The everyday-gate commands above, with the numbers stated.
- **Tier 1b — show the tests bite.** `npm run mutation` (Stryker) and `npm run dry` on the TS
  side; on the Dart side, with no mutation harness configured, a falsification step (see the
  rulebook's PROC-5 for the mechanism, which is not optional — it edits versioned code).
- **Tier 2 — exercise the real thing.** The app run on a device or simulator when the change
  surfaces visually, or the endpoint called for real once endpoints and an environment exist.

"It compiles" and "it should work" are not evidence. Skipping a tier silently is a violation;
asking to skip one is not.

Detail lives in `.claude/agents/`. The rulebook the reviewer cites is
`.claude/conventions/craftsmanship.md` — **this file wins if the two ever conflict**, and the
rulebook gets corrected.

## Architecture rule

**Pure policy separated from IO.** Policy is a function of its inputs with no Canvas, no
socket, no clock and no environment, so it is testable without mocks; the adapter next to it
does the touching. Both precedents are already on disk: `app/lib/design/brand/spec/` versus
the painter beside it, and `packages/server/src/routing.ts` versus
`packages/server/src/adapters/`. New logic follows the same split. On the Dart side the split
is now a red build rather than a precedent: `app/test/architecture/pure_boundary_test.dart`
walks the import graph transitively — through `export` and `part`, so the tokens barrel cannot
smuggle `package:flutter/painting.dart` into a pure root — and reports a per-root file count so
a mistyped root cannot make it vacuously green. Today that bites over `design/**/spec/` and its
14 files, `features/*/policy/` and its 8, and `content/model/` and its 4 — all three roots are on
disk now, and the last two flipped from absent to covered when the round landed. **Import the token
you need, not the barrel:** `tokens.dart` re-exports `brand_typography.dart`, which imports
`package:flutter/painting.dart`, so a pure module reaching for the barrel fails the gate. The root is a **glob, not a list**, so
`design/math/spec/` was covered the moment it existed and no one had to declare it — the next spec
root is free the same way.

## Invariants — do not break without discussing it

**Enforced by a test:**
- Coral (`#FF8A5B`) is error and nothing else; green (`#5ED6A4`) is action and success and
  nothing else; pink is never `error`, `success` or `action` — it is the accent, and
  `BrandColorRole.focus` is an input affordance, not a verdict.
  (`test/design/tokens/brand_colors_test.dart`)
- No blurred shadow, no gradient, no Material elevation. Shadows are hard, blur is always
  zero. (`test/design/no_blurred_shadow_test.dart` walks every screen and asserts exactly
  four things: no gradient, `blurRadius == 0`, `spreadRadius == 0`, and elevation 0 on
  `PhysicalModel` and `PhysicalShape` — add new screens to
  `app/test/design/screen_registry.dart`, which both this gate and `screen_overflow_test.dart`
  read.)
- Every registered screen fits 390x844 at `textScaler` 1.0 and 1.3.
  (`test/design/screen_overflow_test.dart`; the screen list is `test/design/screen_registry.dart`,
  and a viewport can only be excused by an `excused` entry quoting the overflow message that
  earned it.)
- No colour literal outside `app/lib/design/tokens/`, and no `Offset(` literal on a widget
  surface. (`test/architecture/no_color_literal_test.dart` scans all of `app/lib/` except
  `design/tokens/` for `Color(0x`, `Color.fromARGB(`, `Color.fromRGBO(` and `Colors.` — the last
  on a word boundary, since `Colors.` is a substring of `BrandColors.`; `Colors.transparent` is
  the one carve-out. `test/architecture/no_geometry_literal_test.dart` scans `design/widgets/`
  and `features/` for `Offset(`; `design/brand/` is out of scope as the artwork layer, and radii
  and border widths are not scanned at all. Both report how many files they scanned and fail at
  zero.)

- **Nothing you can press is under 48 px**, measured on the rendered screen
  rather than asserted about a widget — a `SizedBox(48)` in a `Row` that ran out of room is 31 px
  wide and the constant says nothing about that. `test/design/touch_target_test.dart` walks every
  registered screen at both viewports and reports the count it swept (today 40 screens, 278
  presses); a screen with nothing to press is legitimate and named in the summary rather than
  failed.

- **Nothing watches you while you work.** `test/design/quiet_while_you_solve_test.dart` walks
  every solving surface — the item in all six families, `0.3 Primer reto`, and all five boards, 13
  screens today — and asserts Aki is on none of them and nothing on them reads as a clock. Both
  halves have their opposite asserted too: she *is* on the verdict screens, in `slip` for a wrong
  answer and `correct` for a right one, and the verdict screen *may* say how long it took. A rule
  that only ever said "absent" would be satisfied by deleting her.

- **A verdict is never drawn by hue alone.** Deuteranopia collapses `#5ED6A4` and `#FF8A5B`, so
  `Verdict` carries an outline and a glyph and **no colour at all** — a call site has to reach for
  a shape because that is all there is, which is the same construction as the sync endpoint
  refusing an `ok` field. What the type cannot prevent is a *second* reach: nothing stops a screen
  pairing `Verdict.correct` with `BrandColorRole.success.color`.
  `test/architecture/verdict_is_not_a_colour_test.dart` scans all 131 files of `lib/` for a file
  naming both, and excuses exactly one — `verdict_ring.dart`, which also draws the ring. It strips
  prose first, because the names it reads for appear in explanations of the rule as often as in
  code.

*(There is nothing left under "encoded as a constant, not yet enforced". Both entries that
lived here — the 48 px floor and the hue-only verdict — now have gates, and the heading comes
back the day something else is written down without one.)*

**Design intent, no code yet to enforce it:**
- Aki has exactly one body part that can be lost and come back: **the curl of her tail** — drawn,
  and `AkiPose.slip` is on the error screen, but nothing checks that the tail is the *only* thing
  that moves. She does not scold and does not look disappointed, which is copy and drawing rather
  than something a predicate can read.

**System invariants for the parts not yet built** (verbatim from ARCHITECTURE.md §4–§5):
- *The prompt travels rendered. The answer never travels online. Offline, a membership
  verifier travels and its verdict is provisional until sync.*
- *`attempts` never accepts UPDATE. It accepts DELETE only through the erasure path
  (`DELETE /v1/me`) and the retention job, both under the `retention_job` role. The request
  path holds no DELETE grant on `attempts`.*
- Rating never runs in Dart. Offline difficulty is fixed by the pack's `ladder_step`.

## Never

- Never add a dependency that collects data, serves ads, or reports analytics.
- Never use `BackdropFilter`. Nothing in `app/lib/` uses one today and no test asserts its
  absence, so this is intent the reviewer enforces by reading, not a red build.
- Never write a color literal outside `app/lib/design/tokens/` — every hue comes from
  `BrandColors`, and state comes from `BrandColorRole`. (`Colors.transparent`, used to switch
  Material's tinting off, is the one exception on disk.)
- Never use a LaTeX library to render math, or the system keyboard for numeric entry.
- Never hand-write authentication crypto — that is Neon Auth's job, and Neon Auth is
  managed Better Auth. It is also why an unlinked device does not sync: it has no
  credential the server could verify, and inventing one is exactly this rule. (HMAC message
  construction for offline verification is ours, and is a cross-stack contract.)
- Never generate puzzles on demand; they go in batches.

## Git

Commit email is `geineryodan@gmail.com` — verify `git config user.email` before committing.

`dev` is the working branch and **pushing to it is authorized**. `main` is protected by the
`protect-main` ruleset: no direct push, no force-push, no deletion — it is reached through a
pull request. Nothing is committed or pushed unless you were asked to.

## Decided

**Auth is Neon Auth, and nothing syncs until an account exists** —
`docs/adr/0002-neon-auth-and-no-sync-until-linked.md`, decided 2026-08-19. Neon Auth is managed
Better Auth with identity in a `neon_auth` schema in our own Postgres and a REST API, so the app
needs no SDK. It exposes **no anonymous plugin** and **no IP-tracking control**, and every
session row carries `ipAddress` and `userAgent` — so a child's device never gets a session at
all. `player_id` is minted on the device, unlinked play is entirely offline, and linking is an
adult's act and the first server contact. **An account is made with an email and a password**
(open sign-up, verification required) — decided 2026-08-19, because the alternative was Google on
Neon's shared consent screen plus two new Flutter dependencies to run a browser redirect.

GHSA-qq9h-g4jm-xgf3 is still closed, by a **narrower and load-bearing** condition: the managed
version is 1.4.18 and cannot be patched by us, so what shuts the advisory is that the
**magic-link and email-OTP plugins are off**. It needs a passwordless sign-in path to collide with
a password registration at the same address, and there is none. **Turning magic-link on reopens
it** — that is one toggle in a console, so it is an invariant, not a preference. It stops mattering
the day the managed version passes 1.6.22. ADR 0002's amendment carries the four conditions and
the queries that verify them.

**The Dart API client is hand-written** — `docs/adr/0001-dart-api-client.md`, decided
2026-08-16 by the F0 spike `f0-dart-client-spike`. `swagger_dart_code_generator` is rejected:
its output fails `flutter analyze --fatal-infos` (3 `unused_import` warnings, under files that
open with `// ignore_for_file: type=lint` and so opt themselves out of the lint set), collapses
optional and nullable into one Dart shape and serializes an absent optional as `null`, silently
absorbs unknown enum values via a synthetic `swaggerGeneratedUnknown`, silently defaults a
missing **required** array to empty, and costs 14 net-new runtime packages against a floor of
zero. It won one rubric row of six — its output is byte-identical across cold runs — which is
not enough under §2's asymmetric criterion.

`app/lib/api/` is therefore hand-written, is an **F3** directory, and is a PURE-2 adapter that
holds no decisions. No `build_runner`, and no CI byte-diff job. The ADR carries a supersede
threshold (600 lines, 15 endpoints, response polymorphism, or auth/pagination/error envelopes),
so this reopens on evidence rather than on memory.
