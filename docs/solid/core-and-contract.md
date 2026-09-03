# `packages/core` and `packages/contract` — a design audit

Audited 2026-08-27 against `main` at `653a17b`. Read-only on code; the only file this change
adds is this one.

Two packages, one audit, because the interesting question is the seam. `packages/core` is the
rederivation machine — zero runtime dependencies, no ambient IO, one committed pack and three
committed goldens. `packages/contract` is the frozen offline pack format plus the emitted API
document. Both are consumed by `packages/server`, and `packages/contract`'s vectors are what the
Dart side is golden-tested against.

---

## Verdict

**These two packages are in good shape, and the two most expensive things in them are both on the
seam rather than inside either one.** The dependency graph is acyclic, the stability is measured
rather than asserted (`packages/contract/src/pack.ts`, `digest.ts`, `diagnosis.ts` and `answer.ts`
carry **one commit each** — the format really is frozen), the churn in both packages is quarantined
in halves that nothing imports at runtime, and the gates that hold the two invariants everything
else rests on — zero runtime dependencies, no ambient IO — are AST walks with working controls
rather than conventions.

> **Finding 1 is fixed**, in `#149` (2026-08-29). It is kept below as written, because the record
> of what was wrong is what makes the fix reviewable, and it carries a resolution note at its end —
> including the correction that **its own safety explanation defends the wrong hazard**. **Read
> finding 1's present tense as the state it audited, not as today's**: a document asserting a
> live defect that
> is no longer live is the same defect as a comment claiming behaviour the code does not have
> (CMT-2). Findings 2 through 7 have not been re-checked since 2026-08-27 and are recorded here as
> audited, which is a different claim from *still true*.

The most expensive thing here is that **the decision `storedAnswer` exists to hold in one place —
*how an exact answer is written down, shape and spelling together* — has three implementations
across the seam, while four comments say it has one.** That is bug #50's exact shape, and #50 is
the reason the function was moved into `contract` at all: it shipped a whole answer of −9 digested
as `-9/1` beside a field saying `integer`, made every generated item in the built pack
ungradeable, disabled the distractor-equals-answer guard in the same stroke, and turned no suite
red. Two of the three producers do not call the function, and the prose is what will stop the next
person finding them.

Second: **`parsePack` cannot be asked the cheap question.** It fuses "is this the format I can
read" with "prove by exhaustive search that every board has exactly one solution", and no door
exists to the first without the second. The Dart reader already made that split deliberately and
said so; the TypeScript side did not, so `POST /packs` re-proves twenty-eight constraint boards
inside a request, bounded only by a board-size ceiling nobody chose for that reason.

One decision is on the wrong side of the pure/IO line — finding 4, the player-facing copy and a
stated product decision living inside a CLI adapter — and it has already cost a module-scope guard
and an unintended mutation exclusion. Everything after that is documentation that went false while
the code around it moved. That sounds minor and is not, in this repository specifically: three of
the seven findings below are wholly comments that retire the very question that would have found
the gap, and two more — findings 1 and 5 — are half that, which is what CMT-2 and CMT-3 exist to
name.

---

## Findings, highest cost first

### 1. Shape-and-spelling is one decision with three implementations, and the prose says one

**DRY, in the form that qualifies: the copies must change together.**

`packages/contract/src/canon.ts:174-199` introduces `storedAnswer` with an explicit charter —
*"One decision, because two was a bug"* — and closes with, verbatim at `canon.ts:186-188`:

> Anything that turns a `(numerator, denominator)` into a stored answer calls this — the builder,
> and the server when it issues a pack — so the two cannot disagree again.

Three producers of a stored answer exist. **One** obeys.

| Producer | Site | How it decides |
|---|---|---|
| pack builder, template items | `packages/core/src/pack/build.ts:99-102` | calls `storedAnswer` ✅ |
| pack builder, authored items | `packages/core/src/pack/lift.ts:127` | `answer.includes("/") ? "fraction" : "integer"` |
| server, grading a rederived item | `packages/server/src/attempts.ts:323-326` | re-implements the `denominator === 1n` branch by hand |

`attempts.ts:323-326` is `storedAnswer(n, d).canonical` written out longhand, under a comment
(`attempts.ts:320-322`) that says *"The same spelling the pack builder uses … See `packages/core`'s
`build.ts`, which learned this the hard way."* It is the same spelling by coincidence of two
matching edits, not by construction.

`lift.ts:127` decides shape from the **raw** field, not from `canonical.value` three lines above it
at `lift.ts:111`. It is correct today only because `requireStoredCanonical` has already refused
anything where the two differ — a guard whose load-bearing role in this line is written down
nowhere.

Two corroborating false statements, both CMT-2:

- `packages/contract/test/public_surface.test.ts:97-99` — *"Two callers derive a stored answer —
  the pack builder and the server issuing a pack"*. The server issuing a pack is
  `packages/server/src/packs.ts:104-127`, which copies a pre-built artifact and derives no answer
  at all. The second caller named by the test does not exist; the real second and third callers
  are the two in the table that do not use the function.
- `canon.ts:187` names the same non-existent caller.

**Cost.** Change amplification on the highest-consequence rule in the repository. Adding a third
member to `ANSWER_SHAPES` (`packages/contract/src/answer.ts:13`), or teaching the spelling anything
about a negative denominator, requires three edits in two packages, and the two that are easy to
miss are the two nobody will grep for, because the comments say they call the function. The failure
mode is silent and end-to-end: #50 shipped a whole answer of −9 digested as `-9/1` while the field
beside it said `integer`, which made **every generated item in the built pack ungradeable** and
disabled the distractor-equals-answer guard at the same time. Nothing in either suite went red.

**Direction.** The seam is `contract`'s public surface. It exports the sharp ingredient
(`renderCanonicalAnswer`, `index.ts:12`) and the safe composite (`storedAnswer`, `index.ts:15`) with
equal prominence, and has no composite at all for the input the other two callers actually hold —
a canonical *string*. Add `storedAnswerOf(canonical: string): StoredAnswer` beside `storedAnswer`
so `lift.ts` has a door, and have `attempts.ts` call `storedAnswer(...).canonical`. Then the
sentence at `canon.ts:186` becomes true, and `public_surface.test.ts` can name the three callers
that exist.

**Resolved (2026-08-29) in #149, as directed, plus a gate the direction did not ask for.**
`storedAnswerOf(canonical: string)` is the second door and `lift.ts` goes through it, keeping its
own refusal and its own message because the door validates; `attempts.ts` calls
`storedAnswer(...)` and no longer writes the `denominator === 1n` branch by hand. The structural
half is that the shape is now **derived from** the spelling rather than computed beside it —
`storedAs` reads the denominator group out of the grammar `canonicalize` accepts by, and both
doors compose it — so the two halves cannot come apart again the way #50's did. The false
sentences went with it: `canon.ts` and `public_surface.test.ts:97-99` both named the server
issuing a pack, and both now name the three callers that exist.

**Latent, and measured to be latent before anything moved.** The three implementations were
compared over 81 `(numerator, denominator)` pairs and the whole of `CANON_INPUTS`, and **they
agreed** — so no digest changed, no artifact moved, and nobody should go looking for a pack whose
grading shifted. What this finding cost was change amplification, not a wrong answer on a device.
The resolution also settled the question the duplication had left open: **`4/1` stays a
fraction**, because pack content may state it that way and folding it would restate an authored
answer.

**The finding's own safety explanation is true and points at the wrong hazard, which is worth
keeping visible.** It says `lift.ts` was *"correct today only because `requireStoredCanonical` has
already refused anything where the two differ"*, and read literally — raw field versus
`canonical.value` — that is exactly what `canon.ts:171` does: `folded.value === stored` or
`not_canonical`. But raw-equals-canonical is not the hazard this finding is about. The subject is
**two implementations disagreeing about shape**, and the guard is silent on shape.
`requireStoredCanonical("4/1")` and `requireStoredCanonical("-9/1")` both return `ok: true`
(measured 2026-09-02), and `-9/1` is bug #50's own string: through `storedAnswer(-9n, 1n)` it is an
`integer` spelled `-9`, through `lift.ts`'s `includes("/")` on the string it is a `fraction`. The
guard lets both readings through because it was never asked the question. Nothing was choosing
between them, and #149 chose — **`4/1` stays a fraction** — which is why the fix derives the shape
from the spelling instead of leaning on a guard that was never load-bearing here. A finding that
credits the wrong mechanism is how the real one gets removed by somebody tidying up.

**The fourth copy is a red build now**, which the direction did not ask for and which is the part
worth carrying forward: `one-way-to-spell-an-answer.test.ts`, in both `packages/core` and
`packages/server`, walks the AST for two prohibitions — naming both shape words is deciding a
shape by hand, calling `renderCanonicalAnswer` is spelling one. Two gates because the halves were
copied separately, and each went red on `main` against the copy its own package held.

---

### 2. `parsePack` fuses a format check with a constraint-solver proof, and only one client wants both

**ISP, and SRP with two actors.**

`packages/contract/src/pack.ts:107` is the one door into the pack format. It runs
`firstContentRejection` (`pack.ts:73-99`), whose puzzle loop (`pack.ts:93-98`) calls `parsePuzzle`,
which for four of the five kinds reaches `checkUniqueSolution`
(`packages/contract/src/puzzle/caged-board.ts:33-42`,
`packages/contract/src/puzzle/kakuro.ts:48-53`,
`packages/contract/src/puzzle/magic-square.ts:56-65`) — a backtracking search over the whole board
with a 500 000-value-trial budget (`packages/contract/src/puzzle/uniqueness.ts:182,254`).

The two actors are distinct people with distinct agendas:

- **The content author**, whose agenda is *do not ship a board a player cannot finish*. This actor
  is real and has a caller: `packages/core/src/puzzles/batch.ts:173` uses `parsePuzzle` as the
  accept/reject oracle in its propose-and-dispose loop. `solution_not_unique` and
  `search_budget_exhausted` exist for this actor and for nobody else.
- **The reader on a request path**, whose agenda is *can I read and grade this artifact*.
  `packages/server/src/packs.ts:117` calls `parsePack` inside `issuedCopy`, i.e. inside every
  `POST /packs`, over the shipped pack's **35 boards — 28 of them numeric** (7 KenKen, 7 Killer,
  7 magic square, 7 Kakuro, 7 sopa de letras). The Dart pack reader is the same actor.

**The split already exists on the other side of the seam, and only there.**
`app/test/content/model/puzzle_fixture_test.dart:30,39` records Kakuro's `solution_not_unique` as
the one tag the Dart reader deliberately does not produce — *"only a solver can see it, and the
builder is …"*. Dart got a cheap door. TypeScript has none, so the server takes the expensive one
by default.

**Cost.** Not primarily latency — today's boards are 3×3 to 6×6 and the measured worst legitimate
case is 34 308 value trials (`uniqueness.ts:175-182`), so a request pays milliseconds. The cost is
*unknown unknowns* and a load-bearing constant in the wrong place:

- `packages/contract/src/puzzle/board.ts:21` caps `size` at 6. That is a **format** decision — it
  is written next to the design's 6×6 ceiling — and it is simultaneously the only thing bounding
  what a request path spends. `uniqueness.ts:9-12` is explicit that the cap "bounds the board, not
  the search". Someone raising the cap to admit a 9×9 board (which plan §5.3 D15 marks *out of
  scope*, i.e. anticipated rather than refused for ever) is making a content decision and will
  silently be making a request-latency decision, with nothing in either file to warn them.
- The call site cannot see it. `packages/server/src/packs.ts:115-116` reads *"Validated, for the
  reason `packOf` is: the same check the client runs"* — which is true and tells a reader nothing
  about a solver. `shipped-packs.ts:62-64` caches its `parsePack`; `issuedCopy` cannot, because it
  validates a freshly-stamped copy.

**Direction.** The seam is `firstContentRejection`'s puzzle loop. Give `parsePuzzle` — or
`parsePack` — a parameter that selects *shape only* versus *shape and playability*, with the
build-time callers (`batch.ts:173`, `emit.ts`, `buildPack`) asking for the proof and the request
path asking for the shape. It is one boolean-shaped choice, so per FUN-2 spell it as a closed enum
or as two named functions; the repository's own idiom here is two named functions, the way
`canonicalize` and `requireStoredCanonical` are two doors onto one rule.

---

### 3. `splitmix64.ts` claims a determinism gate that does not exist

**CMT-3** — a comment claiming a test, which the rule calls CMT-2's nastiest special case because
it retires the question that would have found the gap.

`packages/core/src/prng/splitmix64.ts:24-28`:

> **BigInt and not `Number`.** A seed arrives from a Postgres `bigint`, and `Number` cannot hold
> one. A stray `Number(someBigInt)` in this file would round *identically on every machine*, so it
> would be deterministically wrong everywhere and no cross-machine test could ever see it — which
> is why `determinism.test.ts` refuses the call rather than trusting review.

`packages/core/test/determinism.test.ts` refuses no such call. Its two lists are
`BANNED_IDENTIFIERS = ["Date", "performance", "Intl"]` (`determinism.test.ts:29`) and
`BANNED_PROPERTIES = ["Math.random", "crypto.randomUUID", ".toLocaleString"]`
(`determinism.test.ts:32-36`), plus the rating-scoped `Math.*` list at `:42-48`. `Number` appears
nowhere in that file, and no other test in `packages/core/test/` bans it.

**Cost.** The comment is the reason nobody will add the check, and the invariant it advertises is
the one whose violation is by its own argument undetectable by any other means — a `Number(bigint)`
narrowing is wrong the same way on every machine, so no golden diff and no cross-machine
comparison can see it. `Number(...)` over a bigint already appears elsewhere in the package
(`packages/core/src/templates/arith-integer-subtract/v1.ts:50-51`, `v2.ts:47-48`), safely, because
those values are bounded by the ladder — which means a reviewer who greps will find precedent for
the call rather than a prohibition against it.

**Direction.** The seam is already built and costs four lines: `determinism.test.ts` walks the AST
and knows which file it is in (`scan`'s `relative`, `:80-81`). Add `Number` as a call-expression
sighting scoped to `prng/`, the same way `Math.exp` is scoped to `rating/`, and give it a row in
the control block at `:156-185`. Until that lands, CMT-3's second obligation applies: the comment
must name a file that exists or stop making the claim.

---

### 4. Player-facing copy and a product decision live inside an adapter, and the adapter is excluded from mutation because it is an adapter

**PURE-2** — *"the adapter that performs the IO holds no decisions … and stays thin enough that
nothing worth testing lives in it."*

`packages/core/src/adapters/build-puzzles.ts` holds, in an adapter:

- `VOCABULARY` (`:50-65`) — fourteen Spanish words a player reads in a sopa de letras.
- `TUTORIAL` (`:68-89`) — ten Spanish sentences, one pair per board kind.
- `REFERENCE_SHEET_LINES = 3` (`:100`), whose own doc comment calls it *"a product decision"*.
- `referenceSheetFor` (`:116-152`) — fifteen Spanish sentences and the rule that a sheet states
  objective, then vocabulary, then constraints.

Two costs, both already paid once and visible in the file:

- **The adapter had to be made safe to import.** `build-puzzles.ts:239-253` adds a
  `runFromCommandLine` guard, and its comment records why, measured rather than guessed: *"Without
  it, reading the copy generates a batch … at module scope, built three 4×4 KenKens and wrote
  `puzzles-kenken-4.json` into the package root."* That guard exists purely because the one
  definition of shipped copy is inside a CLI, and it is a discipline every future adapter in this
  package now has to remember.
- **The copy is not mutation-tested, and nobody decided that.** `packages/core/stryker.config.json`
  excludes `!src/adapters/**` — correctly, for IO. `referenceSheetFor` rode along inside that glob.
  Contrast `misconception-copy.ts`, excluded **by name** with a written argument
  (`misconception-copy.ts:14-21`). Same class of artifact, two exclusions, one of them accidental.

The package has already decided where copy goes, in the sibling change that made
`misconception-copy.ts` a value: *"Copy lives in data, not in TypeScript"*
(`packages/core/src/pack/misconceptions.ts:27-32`). `build-puzzles.ts:44-48` argues the opposite —
*"Content, and it lives in the adapter … `src/puzzles/` has no business holding a Spanish word
list"* — and it is right that `src/puzzles/` is the wrong home. `src/pack/misconception-copy.ts`'s
neighbourhood is the right one, and it exists.

**Cost.** `packages/core/test/reference-sheet.test.ts:5-9` imports `referenceSheetFor` and
`REFERENCE_SHEET_LINES` **from `src/adapters/`** to hold the generator's copy and the shipped
pack's copy together — the test's own header records that they had already drifted, and that *"the
first KenKen in the shipped pack carried a sheet the generator has never produced, and it was the
one a player hit first."* A test that must reach into an adapter is PURE-2's own definition of the
adapter being too thick, and here the reach is what makes an unrelated CLI's argv parsing part of
the import graph of a copy test.

**Direction.** The seam is a new sibling of `misconception-copy.ts`, say
`src/puzzles/puzzle-copy.ts` (pure, a frozen value, mutation-excluded by name with the same
argument), leaving `build-puzzles.ts` with argv, `switchKind` and the temp-file write. That also
lets the `runFromCommandLine` guard be judged on its own merits rather than being load-bearing.

---

### 5. The recorded reason `misconceptionCopy()` is a value names a consumer that does not exist, and one doc comment states the opposite of the code

**CMT-2, twice, on the module whose whole design rests on a stated rationale.**

`packages/core/src/pack/misconceptions.ts:157`:

> `/** The fallback's copy, resolved at load so a missing key cannot reach a request. */`

Nothing is resolved at load. `fallbackDiagnosis()` (`:158-167`) calls `misconceptionCopy()`
(`:142-145`), which is `parsed ??= parseMisconceptions(...)` — deliberately deferred to first use,
for the reason argued twenty lines above at `:132-138` and recorded in PROC-5 §0b (56.31 → 93.27,
same tests). The two comments are eleven lines apart and contradict each other; the second is a
survivor of the change that made the first true.

Separately: `misconceptionCopy` and `fallbackDiagnosis` are on the public surface
(`packages/core/src/index.ts:60`) with a reason stated four times over — in `index.ts:57-60`'s
neighbourhood, in `misconception-copy.ts:4-9`, in
`packages/core/test/public_surface.test.ts:61-65`, and in `CLAUDE.md` — and the reason is always the
same: *`packages/server` issues packs inside a request and needs the same words.* **The server
imports neither.** `packages/server/src/` has exactly one `@akimath/core` copy import and it is
`skillName` in `history.ts:1`. The only caller is
`packages/core/src/adapters/build-pack.ts:9,40-41`, inside the same package, at build time —
i.e. the file read that the change removed.

This is **not** the same as the deleted pack generator, and the finding is narrower than that
precedent. `packages/server/src/attempts.ts:412-415` explains that `payload` is `{}` because *"a
diagnosis needs authored content the server does not have yet"*, so a real server caller is one
feature away rather than hypothetical — and the issued pack already carries `skill_fallbacks`,
which is what `parsePack` refuses a pack without.

**Cost.** Cognitive load at exactly the wrong moment. The next person deciding whether copy may go
back into a JSON file — or whether a second value like it belongs in `src/` — has four
corroborating statements of a premise and no way to discover from the code that the premise is not
yet true. The lazy-parse mechanism, which is genuinely clever and genuinely load-bearing, is
justified by a request path that does not exist.

**Direction.** No code change. Correct `:157` in the next commit that touches the file, and reword
the four rationale sites to say what is true — the copy is a value because the *build script* and
the *server that will render a diagnosis* must not have two of them, and the second has not
landed. If the diagnosis payload lands, the premise becomes true and the sentence can go back.

---

### 6. Lazy-parse-on-first-use is a one-off, not a pattern, and the second site of the same shape was not converted

The brief asks whether deferred parsing is now a pattern here. **It is not.** Two sites in
`packages/core/src/` do work at module scope; one was converted and one was not.

- `packages/core/src/pack/misconceptions.ts:140-145` — converted, argued, and the source of
  PROC-5 §0b.
- `packages/core/src/templates/index.ts:17-20` — `CORE_REGISTRY = registryOf([...])`, evaluated at
  import. `registryOf` **throws** on a duplicate key
  (`packages/core/src/registry.ts:19-21`: `two templates claim ${key}`). That is precisely the
  shape §0b names: *anything a module does at import time turns a bad edit into an import failure,
  and an import failure is not a test failure.* The module is imported by `src/index.ts:45`,
  `src/golden.ts:3` and `src/adapters/build-pack.ts:6`, so an import failure there takes the public
  surface, the golden emitter and the pack build with it.

I am **not** reporting a mutation score: there is no `node_modules` in this worktree, I ran no
Stryker, and PROC-5 forbids reporting a number I did not produce. The structural fact is the
finding, and it is checkable by reading.

**Cost.** Low today and asymmetric. One template family ships, so a duplicate-key edit is
implausible; the cost arrives with the second family, which is the whole point of the registry, and
it arrives as a suite that reports the wrong thing rather than as a failure. Note also that
`packages/core` runs Stryker with `coverageAnalysis: "all"` and `packages/contract` with
`"perTest"` — I checked `git show 79a6ac8` and the core value predates the lazy-parse change, so
the recorded 56.31 → 93.27 attribution is sound and not a config artefact.

**Direction.** `coreRegistry()` (`templates/index.ts:34-36`) is already the exported door and is
already a call; making it `built ??= registryOf([...])` moves the throw to first use. Stating the
blast radius rather than understating it, since that is what §0b is about: the two in-package
callers reach for the **constant**, not the call — `golden.ts:3,39,48` and
`adapters/build-pack.ts:6,58,64` — so both change too. Five or six lines across three files, and
the duplicate-key throw then lands in a test instead of in an import.

---

### 7. The digest golden's own documentation states a salt shape the format forbids

**CMT-2**, on the artifact the Dart implementation is written against.

`packages/contract/src/digest-vectors.ts:23-26` describes `DIGEST_GOLDEN_SALT` as:

> thirty-two bytes as sixty-four hex characters, **the shape a real `pack_salt` has**

A real `pack_salt` is **sixteen bytes as thirty-two hex characters**:
`packages/contract/src/pack.ts:41` is `z.string().regex(/^[0-9a-f]{32}$/u)`,
`packages/core/src/pack/declaration.ts:66` is the same regex, and
`packages/server/src/adapters/pack-repository.ts:14` says so in prose. The golden salt is twice
the length any pack may carry.

**Cost.** Small but on the seam, and of the kind this repository has been bitten by. The parity
table is *"what makes the second implementation a matter of passing a test rather than of reading a
paragraph carefully"* (`digest-vectors.ts:14-16`), and the paragraph beside it is wrong. HMAC
accepts any key length, so the vectors are correct and Dart passes; what the comment costs is a
Dart or future reader who takes the fixture as evidence of the salt's shape and validates the wrong
length, or who widens `PackSchema`'s regex to "match the golden". `answerDigest`
(`packages/contract/src/digest.ts:16-20`) validates neither length nor hex-ness, so nothing
downstream would object.

**Direction.** Fix the sentence, and do **not** touch the constant. `DIGEST_GOLDEN_SALT` keys every
row of `contract/fixtures/digest.golden.json`, the artifact `app/lib/content/answer_digest.dart` is
held to and which was emitted from TypeScript before the Dart side existed so the two could not
drift; shortening it re-emits a frozen cross-stack fixture and pushes a churn commit through the
`contract` job's byte-diff to correct a comment. It would also buy nothing the comment's own
argument asks for — a 64-hex salt already exercises hex *decoding*, which is the property
`digest-vectors.ts:23-26` says it was chosen for. Say instead that a real `pack_salt` is sixteen
bytes as thirty-two hex characters and that the golden salt is deliberately longer.

---

## The seam between the two packages

The brief asked for a reading of the seam rather than a verdict on it, and the honest reading is
that **it is in good shape and the two packages sit at the right point on the REP/CCP/CRP line.**

**Direction and acyclicity.** `packages/core` → `packages/contract` → `zod`, and nothing else.
`packages/contract` imports no first-party package. No cycle exists between directories inside
either package (I enumerated every `from "…"` in both `src/` trees). ADP holds objectively.

**Both packages have the same two-halves shape, and in both the churn is in the half nothing
imports.** That is the structural fact worth carrying forward:

| | runtime half (reachable from `index.ts`) | build-time half (reachable only from `adapters/`) |
|---|---|---|
| `core` | `rational`, `prng`, `registry`, `template`, `templates`, `manifest`, `rating`, `skill-names`, `misconceptions` | `pack/{build,declaration,distractors,lift,puzzles,seeds}`, all of `puzzles/` |
| `contract` | the pack format, canon, digest, diagnosis, stimulus, puzzle, vectors | all of `openapi/` |

Measured churn since each file was created (`git log --name-only` over `main`):

- `packages/contract/src/openapi/document.ts` — **14 commits**, the most-edited file in either
  package by a factor of three.
- `packages/contract/src/pack.ts`, `digest.ts`, `diagnosis.ts`, `answer.ts`, `skill-map.ts`,
  `keypad-layout.ts`, every `stimulus/*` and every `puzzle/*` — **1 commit each**.
- `packages/core`: the runtime half is 1–2 commits per file; the build half is 4–6
  (`pack/build.ts` 6, `adapters/build-pack.ts` 6, `adapters/build-puzzles.ts` 5).

**So the SDP/SAP answer is no.** Neither package has a reason to change more often than its
dependents can absorb. `openapi/document.ts` changes every time an endpoint lands, and it is the
one file in `contract` that is volatile — but it is exported from nowhere
(`packages/contract/src/index.ts` omits the whole `openapi/` subtree), imported only by
`src/adapters/emit.ts:8`, and reached by the server exclusively through the emitted artifact
`contract/openapi.json` (`packages/server/test/support/contract.ts:19`). The volatile part is
already behind a build-time boundary; the stable part is a set of data definitions and pure
functions, which is what SAP asks a stable component to be.

**Where the tension actually sits.** REP and CCP push these two together — one `npm run emit`, one
CI job, one artifact directory that is byte-diffed as a unit. CRP would pull `openapi/` out of
`contract` and `puzzles/` + `pack/` out of `core`. There is a real, small cost to the current
placement and it is discoverability, not coupling: `packages/contract`'s own `description` field
says *"the offline pack format, its canonicalizer and its emitted artifacts"* and does not mention
791 lines of API document, and nothing reachable from `index.ts` leads to it. I would not move
anything today — the measurement says the churn is contained — but the description should name both
halves, and the day `contract` gains a second consumer that only wants the pack format, CRP wins.

**What crossed the seam correctly, and stayed correct.** Both documented moves hold up:
`toManifestEntry`/`fromManifestEntry`/`templateRefOf` are genuinely the one definition
(`packages/core/src/manifest.ts`), with both kinds in one file since 0005, one producer per kind,
and the server reading them through `attempt-repository.ts:2` rather than matching a comment;
`storedAnswer` is in the right package, and finding 1 is about its callers, not its home.
`manifest.ts:72-81` even handles the reverse pressure honestly: it needs contract's digest regex,
may not import it, spells it locally, and points at `test/template/manifest.test.ts` running both
over the same probes.

**What is still on the wrong side of the seam.** One thing, and it is finding 2: the *playability
proof* is a build-time obligation living inside the format's only reader. `packages/core`'s
`puzzles/batch.ts` is the actor that wants it, and it is in the package that already owns
generation. The proof does not need to move packages — a `contract` that can be asked either
question is enough — but today the obligation is on the wrong side of *the request boundary*, which
is the seam that matters more.

---

## What this module gets right, and why

Recorded because these are patterns worth copying, not as padding.

1. **Gates that walk an AST, with a control that proves the walker can see.**
   `packages/core/test/determinism.test.ts` and `test/import_boundary.test.ts` both (a) report how
   many files or nodes they walked and fail at zero (PROC-10), and (b) carry a *control* — a
   synthetic tree with a real violation in it — so a walker that is simply broken is
   distinguishable from a clean codebase without committing a violation to shipped source
   (`determinism.test.ts:156-185`, `import_boundary.test.ts:134-157`). `import_boundary`'s walker
   takes `read` as an injected closure so the control needs no filesystem at all. This is the best
   gate design in the repository and the reason the "zero runtime dependencies" claim is a fact
   rather than a manifest entry.

2. **A scoped permission a flat ban could not express.** `determinism.test.ts:38-48` permits
   `Math.exp/log/sqrt/pow/fround` **only** under `src/rating/`, because Glicko needs them and a
   generator that reaches for a transcendental depends on a libm nobody pinned. The file says so.
   That is the difference between a rule and a lint.

3. **`Rational` is a method-free frozen interface, and the surface test enforces the reason.**
   `packages/core/src/rational.ts:1-21` argues that the obvious `toString` passes every arithmetic
   test and is silently wrong, because the module reduces and the frozen format does not.
   `test/public_surface.test.ts:83-117` then bans any export matching
   `/render|format|canonical|stringify|toString|print|display/i` **and includes a control** proving
   the regex fires on `renderCanonicalAnswer` and not on `rationalOf`. Structure and gate, arguing
   the same point from two directions.

4. **Set equality on the public surface, with the reason written down.**
   `packages/contract/test/public_surface.test.ts:41-53` records that writing the list was itself
   the finding — the five prior assertions mentioned sixteen of thirty-six exports, so twenty
   shipped with no surface coverage. `packages/core/test/public_surface.test.ts:6-13` cites that
   as precedent. A surface test that fails in *both* directions is what makes adding an export a
   decision.

5. **Frozen history modelled as files, and the duplication defended in writing.**
   `src/templates/README.md` is the jscpd exclusion's reason, and **the excuse is earned**: v1
   (`arith-integer-subtract/v1.ts`) and v2 differ only in ordering the terms below ladder step 3,
   and a shared helper both called would be *"a single place where changing one changes both, which
   is exactly what a version number exists to prevent"* (`v2.ts:8-13`). This is Metz's point
   exactly — duplication is cheaper than the wrong abstraction — and it is one of the few places
   where the *safety* argument is stated rather than assumed. The exclusion is scoped to one
   directory, which is the right size.

6. **Counter-linear PRNG addressing, argued from correctness rather than speed.**
   `packages/core/src/prng/splitmix64.ts:57-81`: `wordAt(seed, index)` exists so that the *n*-th
   draw is a function of `(seed, n)` and nothing else — *"there is nothing to forget to reset and
   nothing to advance twice"* — verified against a stateful walk in
   `test/prng/counter_linearity.test.ts` rather than assumed. `MAX_REJECTIONS`
   (`splitmix64.ts:157-174`) exists because a falsified `MASK64` made the loop *hang*, and a hang
   reports nothing; turning it into a throw makes a corrupted build say so. Both are the kind of
   reasoning that only shows up after somebody was actually bitten.

7. **Golden artifacts replayed from disk, with the limit of the evidence stated.**
   `packages/core/test/golden.test.ts:9-21` says outright that a test calling the builder twice
   proves determinism and nothing else, that reading the committed file is what makes these
   regression gates, and that they are *not* correctness proofs — correctness comes from Vigna's
   compiled reference, Glickman's published worked example, and a shipping item. An audit rarely
   sees a test that names what it does not prove.

8. **Content refused rather than approximated, everywhere.** `declaration.ts:149-160` *refuses* a
   `skill_id` on a template source rather than ignoring it, because *"an ignored field looks like it
   works"*; `lift.ts:76-80` refuses an expression that is not exactly four tokens rather than
   dropping the tail; `canon.ts:84-88` rejects invisible characters rather than stripping them,
   because *"silently deleting a character a child cannot see is how a wrong answer becomes a right
   one"*; `build.ts:144-150` fails the build for a distractor whose misconception has no copy.

9. **`CANON_INPUTS` covers every rejection tag it can produce.** I checked all seven of
   `canon.ts:15-22` against `canon-vectors.ts:13-49`: `empty` (`""`, `" "`), `zero_denominator`
   (`1/0`), `non_numeric` (`x+1`, `1/-2`), `non_ascii_digit` (`٠`), `invisible_character`
   (U+200B), `combining_mark`, and `not_canonical` via the stored direction on `007`/`" 5 "`. The
   five vectors added later (`canon-vectors.ts:34-48`) carry their own incident report — a `-0/5`
   defect shipped in Dart through the one gap in the original nineteen — and buy Dart coverage with
   no Dart edit, because the parity test iterates whatever the list holds. That is the right shape
   for a cross-stack fixture.

10. **Both packages know which half of themselves is the adapter, and say so at the top of the
    file.** `emit-golden.ts:8-14` calls itself *"the only filesystem writer in this package, and it
    holds no decision"* and is 25 lines. `build-pack.ts` writes through a temporary file because
    `> out` once destroyed a committed artifact on a refusal, and records that. Finding 4 is the
    one place this discipline slipped.

---

## Coverage

**Read completely.** `CLAUDE.md` (790 lines) and `.claude/conventions/craftsmanship.md` (522
lines), before any source. Every `.ts` file under `packages/core/src/` and
`packages/contract/src/` except the six one-page `stimulus/*` payload modules and
`contract/src/openapi/downconvert.ts`, which I skimmed. `packages/core/src/templates/README.md`.
Both `stryker.config.json`, both `.jscpd.json`, both `package.json`.

**Read for context, not audited.** `packages/server/src/{packs,attempts,history,routing}.ts` and
`src/adapters/{shipped-packs,pack-repository,attempt-repository}.ts` — these are the seam's other
side and findings 1, 2 and 5 depend on them; `packages/server/migrations/0001,0002,0005,0006` and
`schema.sql` for the column names and types the two packages claim to match;
`.github/workflows/ci.yml`; `app/lib/content/model/puzzle_reader.dart` and
`app/test/content/model/puzzle_fixture_test.dart` for finding 2's seam.

**Tests read in full.** `core/test/{determinism,import_boundary,public_surface,golden}.test.ts`,
`core/test/reference-sheet.test.ts` (partially), `contract/test/{public_surface}.test.ts`,
`contract/test/fixture-files.ts`.

**Checked and clean.**
- **ADP.** Enumerated every import specifier in both `src/` trees. Acyclic between packages and
  between directories within each package.
- **LSP across the sealed pairs.** All five `PuzzleValidator`s and all six `PayloadValidator`s
  return `tag | null` and none throws; the two `validator()` wrappers
  (`puzzle/index.ts:35-43`, `stimulus/index.ts:42-50`) give every sibling the same
  shape-failure behaviour. `checkWordSearch` skips `checkUniqueSolution`, which is a genuine
  difference in obligation, not a substitutability defect — a sopa de letras has no constraint
  problem. `fromManifestEntry` returns `null` and `resolve` throws, and
  `manifest.ts:102-113` explains why that asymmetry is deliberate and which caller each serves.
- **PURE-1.** No `Date`, `Math.random`, `Intl`, `performance`, `toLocaleString` outside the
  rating scope in either `src/`; the AST gate covers `packages/core` including `adapters/`, and
  `packages/contract`'s only IO is `src/adapters/emit.ts`.
- **The determinism premise.** Verified rather than trusted: `.github/workflows/ci.yml:655-711`
  has a `core` job that runs `npm run emit` and `npm run build:pack` and byte-diffs
  `packages/core/golden/` and `packages/core/pack/` **staged**, and `gate` (`:733`) needs it. The
  brief's premise holds. *Note for the next reader: `CLAUDE.md`'s list of CI jobs omits `core`,
  which is stale documentation in `CLAUDE.md` rather than a defect in this module.*
- **The dependency premise.** `packages/contract/package.json` pins `zod` at exactly `4.4.3` as
  its only `dependencies` entry; `packages/core/package.json` has no `dependencies` key at all and
  carries `@akimath/contract` as a `file:` **dev**Dependency, which
  `test/import_boundary.test.ts` keeps out of the public surface's reach.
- **`CANON_INPUTS` tag coverage** — all seven, listed above.

**Could not judge, and why.**
- **Mutation scores and suite counts.** This worktree has no `node_modules` in either package and
  the audit is read-only, so I ran neither `npm run verify` nor `npm run mutation` nor `npm run
  dry`. Every claim above is from reading. Where the brief's context named a number
  (56.31/93.27, 248, 340) I did not reproduce it and have not asserted it as current. Finding 6 in
  particular states a structure, not a score.
- **Whether `POST /packs`'s uniqueness re-proof is measurably slow today.** I did not benchmark
  it, and I do not claim it is. Finding 2's cost is stated as unknown-unknowns and a misplaced
  constant, which is what I can support.
- **`contract/src/openapi/downconvert.ts` (222 lines)** — skimmed only. It is a 3.1→3.0.3
  transform with its own suite (`openapi-downconvert.test.ts`) and no consumer outside
  `document.ts`; a reader extending this audit should start there.
- **The six `stimulus/*` payload modules** — read their shapes and their `check*` signatures for
  the LSP sweep, not their contents line by line. Each is 19–28 lines with one committed golden and
  one committed rejection fixture.

**Candidates discarded: thirteen.** Recorded so the next reader knows how hard this looked.

1. `answerDigest`'s unvalidated `packSaltHex` (`digest.ts:16-20`) — `Buffer.from(bad, "hex")`
   truncates silently. Discarded: the column is `bytea` and the hex is `encode()`-derived
   (`pack-repository.ts:116`), and `test/issue-pack.test.ts` closes the loop end to end. No
   demonstrated cost. (The related *comment* about the golden salt's shape is finding 7.)
2. `Q = Math.log(10) / 400` at module scope (`glicko.ts:22`) — module-scope work, but it cannot
   throw, so PROC-5 §0b does not reach it.
3. `emit.ts:84` resolves the contract root by counting four `..` segments. PROC-9 is about tests
   under the Stryker sandbox; this is an adapter run by `npm run emit`, and the *test-side* reader
   (`test/fixture-files.ts:10-29`) walks up correctly and says why.
4. `checkSumReachable(0, …)` (`board.ts:193-204`) — `slice(-0)` returns the whole array, so a
   zero-cell cage would compute a nonsense ceiling. Unreachable: every cage schema is
   `.min(1)` or `.min(2)`.
5. Length of `openapi/document.ts` (344) and `uniqueness.ts` (270). Not findings; the metrics tool
   owns this and there is no TS threshold to breach.
6. Exhaustive switches over sealed types in `fromManifestEntry`, `parseSource`, `ruleSatisfied`,
   `rulePrunable`, `arithmeticHolds` and `referenceSheetFor`. Explicitly not OCP violations.
7. The v1/v2 template duplication. The excuse is earned; see "gets right" #5.
8. The four `generate*Batch` wrappers (`batch.ts:49-100`) as shallow modules. Each names a distinct
   request type, `collectBatch` is the deep part, and Ousterhout's objection is to chopping a deep
   thing up, which this is not.
9. `validator<Payload>` duplicated near-verbatim between `puzzle/index.ts:35-43` and
   `stimulus/index.ts:42-50`. Nine lines over two independent closed tag unions; no evidence the
   copies change together, so per Metz this is not a DRY finding.
10. `openapi/` as a CCP split inside `contract`. Measured instead of asserted, and the measurement
    said the churn is quarantined — reported as the seam reading, not as a finding.
11. `packages/core/src/template.ts:73` and `test/public_surface.test.ts:51` still say
    `offline_packs.template_refs`; migration 0005 renamed the column to `item_refs`
    (`0005_…sql:39`, `schema.sql:94`). Observation rather than a finding: `CLAUDE.md` carries the
    same stale spelling, so this is the project's own prose to correct, and `manifest.ts:7` — the
    file that owns the shape — already says `item_refs`.
12. `src/templates/README.md:17-19` claims *"a copy-paste anywhere else still fails the gate"*.
    `.jscpd.json` sets `threshold: 1`, and PROC-5 records that this means `npm run dry` exits 0
    with real clones in it. Discarded as a finding because PROC-5 already owns the general fact and
    the README's substantive argument — the exclusion, and why — is correct and earned; the last
    sentence is worth softening the next time the file is touched.
13. The existence of any comment. Never a finding here, and in this module the comments are the
    single most valuable artifact after the gates.
