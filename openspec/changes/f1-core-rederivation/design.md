## Context

See `proposal.md` — Why, and `specs/domain-core/spec.md` for the requirements. What follows is only
what has real alternatives worth recording.

Three facts on disk shape everything, and two of them contradict the planning documents. They were
checked against the files, not recalled.

- **The rederivation key is a quadruple, not a triple.** `ARCHITECTURE.md` §3 says
  `(template_id, template_version, seed)`. `packages/server/migrations/0001_initial.sql` declares
  `issued_items` with `ladder_step smallint NOT NULL` beside those three, and `template_refs` is
  documented as carrying all four. The migration is applied and forward-only; the schema wins.
  Nothing in a seed says which ladder step it was issued at, which is precisely why the column
  exists.
- **`user_skills` is Glicko-1 shaped and stores float32.** `(player_id, skill_id, rating real,
  deviation real, updated_at)` — no volatility column, which Glicko-2 would need. `real` is float32,
  and D11 turns that from a limitation into the thing that makes a byte-exact fixture possible.
- **Nothing in the schema supplies an opponent rating.** `template_stats` has no rating column and
  `ladder_step` is a difficulty label, not a rating. See Open Questions.

## Goals / Non-Goals

**Goals** (beyond `proposal.md`'s)

- Every constant that could be mistranscribed is anchored to something outside this repository.
- Every golden artifact is emitted by code and replayed from disk, never hand-written and never
  asserted against the function that produced it in the same breath.

**Non-Goals**

- Byte-exactness of intermediate floating-point values. ECMAScript specifies `Math.exp`, `Math.log`
  and `Math.pow` as implementation-approximated; the guarantee is at the output boundary (D11).
- A general expression engine. One reference template, one shape.

## Decisions

### D1 · `@akimath/core`, no `dependencies` key, and the frozen contract as a **dev** dependency

The apparent deadlock — core must reuse the contract's canonicalisation rule or duplication
returns, but core must have zero dependencies so it cannot import it — dissolves once the
relationship is named correctly. **Core is a producer; the contract is the frozen acceptor.
Acceptance is a test-time concern.** So `@akimath/contract` sits in `devDependencies`, used only to
prove core's output is loadable, and the `dependencies` key stays absent so the manifest-reading
gate passes literally, with no carve-out for workspace siblings.

*Alternatives.* **`workspace:*` in `dependencies`** — a gate that reads `package.json` cannot tell a
sibling from `drizzle-orm`, so the invariant dies in the one-line diff `ARCHITECTURE.md` §3 warns
about; it also drags `zod` in transitively, because the contract's index re-exports every schema
module. **A zod-free subpath export** — sidesteps zod, not the manifest. **No reference at all** —
cheapest, and forfeits the only mechanism proving a generated item is actually loadable.

*The name.* `ARCHITECTURE.md`, `CLAUDE.md` and the plan all say `@aki/core`; the two packages on
disk are `@akimath/server` and `@akimath/contract`. Consistency with disk wins and the three
documents are corrected in the same commit — this is a decision, not a silent fix, so it is
recorded here and listed as an open question in case Ervin wants the other answer.

### D2 · Vendored splitmix64, addressed by index rather than by advancing state

`mix64(seed + (index + 1) × GAMMA)` is bit-identical to a stateful walk of the same length — this
was verified over twenty outputs at seeds `0`, `1`, `2⁶³` and `2⁶⁴−1`, not assumed. That property is
what makes statelessness structural: there is no cursor to forget to reset, and a generator cannot
accidentally depend on how many draws something before it took.

Constants and shifts are transcribed from Vigna's public-domain reference with the URL beside them.

*Alternatives.* **cyrb128 + sfc32** — the snippet `ARCHITECTURE.md` §3 names, and the same line
records that its widely-copied golden vector is wrong; a 32-bit design also forces a second
implementation for 64-bit seeds. **A stateful generator** — the obvious choice, and it makes draw
count part of the contract by accident (see Open Question 8).

### D3 · The golden vector is emitted, and the emitter is not the oracle

The crux, because a vector the code emits and then asserts against itself is circular. Three
layers, and only the first two carry correctness:

1. **The external anchor** — the vendored kernel checked against Vigna's own published outputs.
   Correctness comes from outside the repository.
2. **A differential oracle** — a second, independent implementation in the test, so a transcription
   slip has to happen identically twice.
3. **The committed artifact** — emitted by an adapter, committed, and *replayed from disk* by a test
   that reports how many vectors it compared. This layer is a regression gate, not a correctness
   proof, and the distinction is written down so nobody mistakes a green replay for validation.

**Stryker cannot substitute for this.** It ships no numeric-literal mutator and no bitwise mutator,
so nothing it does reaches the six magic constants or the mask — the highest-risk sites in the file.
A high score here is green carrying no information (PROC-11). The manual falsification matrix in
`tasks.md` is mandatory, not supplementary.

### D4 · A rational has no `toString`, and core never renders an answer

The likeliest mistake in this change is the obvious one: give `Rational` a `toString`, watch every
arithmetic test pass, and silently make `4/8` and `6/4` in the shipped starter pack ungradeable
because the reducing form disagrees with the frozen canonical form.

So `Rational` is a **method-free frozen interface**, there is no `toString` to reach for, and a
public-surface test fails on any export matching `/render|format|canonical|toString/`.

### D5 · `renderCanonicalAnswer` lands in the contract, calling the private join, in this change

Rendering is the inverse of canonicalising and the two must not be able to disagree. There is
exactly one implementation of the join and both sides call it. Two canonicalisers already exist
across two languages and their differential fuzz over 22,440 inputs found 4,916 tag-only
divergences; a third copy would reorder a character class, pass an accept/reject test, and break
every caller switching on the tag.

**And the cross-language vector set is extended in the same change** — with `0/5`, `-0/5`, `-3/4`,
`4/1`, `12/7`. Its 19 vectors contain no negative-zero fraction, and that exact hole is how the
`-0/5` defect shipped in Dart. Extending it buys Dart coverage of every rendered shape with zero
Dart edits, because the Dart parity test iterates whatever the fixture contains.

### D6 · Outputs are narrowed with `Math.fround`, which is what makes the rating fixture byte-exact

`Math.exp`, `Math.log` and `Math.pow` are implementation-approximated, so Glicko cannot be
byte-exact across engines the way BigInt arithmetic can. But `user_skills` stores `real` — float32 —
and narrowing at the output boundary absorbs the spread: perturbing the internals by up to **2²⁴
ULPs** does not move the float32 result, while a real cross-engine difference is one or two ULPs.
Roughly seven orders of magnitude of margin.

So the fixture is byte-exact *at the stored precision*, and the test proves the margin rather than
asserting it — it perturbs the internals and shows the output holds.

**The mechanism must be stated correctly or it gets misapplied**: this works because the stored type
is narrower than the computed one. It is not a general licence to call floating point deterministic.

### D7 · Glicko takes the opponent rating as a parameter and decides nothing about its provenance

Nothing in the frozen schema supplies one. Core is correct under every candidate — a fixed
ladder-step table, a later migration adding rating columns to `template_stats`, or derivation from
the aggregates already there — and choosing here would freeze a decision that belongs to
`f3-attempt-sync`. See Open Questions 1.

### D8 · The determinism gate is a TypeScript AST walk, not an ESLint rule

`ARCHITECTURE.md` §3 and the plan both say `no-restricted-globals`. That would mean ESLint as a new
dev dependency and a config file, in a repository that has no ESLint anywhere, to catch six
identifiers. An AST walk over `src/**` using the TypeScript compiler already present is fewer moving
parts, and it can do what the lint rule cannot: **scope the permission**. The transcendentals are
allowed in the rating modules and refused everywhere else, which a flat global ban cannot express.

Recorded as a deviation from two documents rather than performed quietly.

### D9 · Both sides of every cross-package edge are gated

This change creates two edges and the existing filters see neither. `packages/core`'s parity suite
depends on the frozen contract, and the contract's emitted fixture binds the **Dart** canonicaliser.
So: the `core` filter watches `packages/contract/**` and `contract/**` as well as its own tree, and
the `dart` filter gains `contract/**` — `ARCHITECTURE.md` §8 always said the Dart job runs on
`dart` ∨ `contract` and the workflow only ever implemented the first half.

A gate that watches one side of an edge is a gate that reports green while the other side drifts.

## Risks / Trade-offs

- **A reducing `toString()` on `Rational`** → D4 removes the thing to reach for, and a public-surface
  test refuses to let one back in.
- **A third canonicaliser "because it's only a regex"** → D5: one join, two callers.
- **Validating against the existing 19 vectors alone** → they are a floor, not a spec, and they have
  a known hole. D5 extends them.
- **Enshrining a hand-recalled constant** → the failure `ARCHITECTURE.md` §3 records. Every numeric
  in this design is an *obligation on a committed test*, never a stated fact: the reference stream's
  values, the seed that reproduces the shipped item, and Glickman's constants are all red-until-green.
- **Mistaking the Stryker score for proof the golden bites** → D3.
- **A golden no required check reads** → `req-core-gates`, with a falsification: change a constant
  and watch CI go red.
- **A stray `Number(bigint)` in the draw path** → it rounds *identically on every machine*, so it is
  deterministically wrong everywhere and no cross-machine test can see it. The AST gate refuses
  `Number(` on a BigInt-typed expression in the PRNG modules.

## Open Questions

Answerable later without changing the specs or the task breakdown, except where marked.

1. **How does a template become an opponent rating?** Three candidates, none decided on disk.
   Core is correct under all of them (D7), but **nothing can rate a real player until this is
   settled**. Highest priority, and it belongs to `f3-attempt-sync`.
2. **Where does `session_id` live?** `ARCHITECTURE.md` says it rides on every attempt; the frozen
   `attempts` table has no such column. Either a later migration adds it, or it is a request-body
   field used for in-flight grouping and discarded. And what happens when one session spans two
   sync calls?
3. **The package name** — `@akimath/core` (D1, matching disk) versus `@aki/core` (three documents).
   Either way three documents change; this is flagged rather than assumed.
4. **Is there a magnitude cap on a graded answer?** The frozen grammar's `\d+` is unbounded. Content
   policy, not format.
5. **Are draw counts a frozen public contract?** If the rejection threshold ever changes, every
   downstream draw shifts and every generated item changes although each function is still correct.
   Probably must be frozen behind a version bump — but that is a policy call about what
   `template_version` means.
