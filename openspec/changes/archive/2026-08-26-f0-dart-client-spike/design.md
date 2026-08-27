# Design — f0-dart-client-spike

## Context

`ARCHITECTURE.md` §2 (`ARCHITECTURE.md`:121-138) is the authority here and is not restated: it
fixes OpenAPI **3.0.3**, zero response polymorphism, the two surviving options, and the exit
criterion. What §2 does **not** say is how to run the spike without contaminating the repository,
which three schemas count as *representative*, what *"better"* means when the judgement lands, or
where the answer is written down. `docs/adr/` holds a single `.gitkeep`, so even the ADR's file
name is undecided. Those five gaps are what this document closes.

Two facts about this machine bound the work and are inputs, not findings: `packages/server` has no
`dependencies` key, so **Zod is not installed anywhere in the repo**; and `app/` runs Flutter
3.41.8 / Dart SDK `^3.11.5` with `flutter_lints ^6.0.0` and `--fatal-infos` as the enforced gate
(`CLAUDE.md`, *Commands*).

## Goals / Non-Goals

The proposal's scope stands; these are the design-level boundaries on top of it.

**Goals:**

- Produce a judgement that survives the session — reproducible from the ADR alone, after the
  scaffold is gone.
- Leave the repository's committed diff **documentation-only**, provably.
- Make *"better than hand-written"* a rubric someone else could apply to the same inputs and reach
  the same answer.

**Non-Goals:**

- Choosing the Zod → OpenAPI emitter. That is `f1-contract-emitter`'s decision (Decision 4).
- Keeping the spike's code. Nothing built here is a starting point for anything (Decision 2).
- Evaluating anything that needs a JVM or Docker (Decision 5).

## The PURE boundary

**No new module lands on either side of it** — this change writes documentation. The statement the
rulebook wants is about the module the decision *governs*, and it is a constraint on both options
rather than a consequence of picking one:

`app/lib/api/` is an **adapter** (PURE-2). It owns the socket, the serialization and the status
codes, and it holds **no decisions** — no retry policy, no verdict interpretation, no
offline-fallback rule, no canonicalization. Those are PURE-1 modules elsewhere, and the invariant
in `CLAUDE.md` that *the answer never travels online* is decided in policy, never in the client.
This matters to the spike because it removes a whole class of argument from it: a generated client
is a PURE-2 adapter by construction and cannot drift, while a hand-written one can, so the ADR
records the constraint explicitly as a cost of the hand-written option. It is **not** a reason to
prefer codegen — §2's criterion is about the code, and a 250-line adapter is small enough to read.
The ADR says so rather than leaving a reviewer to rediscover it in F3.

## Decisions

### Decision 1 — the change declares no capability and sets `skip_specs: true`

**Chosen.** `openspec/changes/f0-dart-client-spike/.openspec.yaml` carries `skip_specs: true`.
Verified against the installed CLI (1.9.0) before writing anything: `openspec status --change
f0-dart-client-spike --json` reports `specs` as `"status": "skipped"`, and `openspec instructions
tasks` lists the `specs` dependency as `"done": true, "skipped": true` — so the artifact DAG is
satisfied, not merely the validator.

**Alternative considered and rejected:** a one-requirement delta spec whose scenarios assert that
the ADR exists, records the exit criterion, and records the determinism result. It is genuinely
testable — a script can read the file. It was rejected because a spec is a contract on *system
behaviour*, and no behaviour changes here; the schema's `specs` instruction names this exact case
(*"pure refactor, tooling, docs"*) and warns in the same breath not to *"invent a requirement just
to satisfy validation"*. The verifiability that spec would have carried is not lost: it moves to
`tasks.md`, where `openspec/config.yaml` already requires each task to name the check that proves
it. The trade is that those checks are not machine-enforced after archive — accepted, because a
spike is not archived into a living contract.

### Decision 2 — the spike is built outside the repository and torn down inside the change

**Chosen.** All spike scaffolding — the throwaway Node package that holds Zod, and the throwaway
Dart package that receives the generated client — lives in a directory **outside the working tree**
(`$TMPDIR/akimath-spike-a/`, or any path the operator prefers that `git status` cannot see).

The failure this prevents is concrete and would not be caught by the forbidden-paths list:
`swagger_dart_code_generator` needs `build_runner`, `json_serializable`, `json_annotation` and a
transport, and adding them to `app/pubspec.yaml` to "just try it" rewrites the versioned
`app/pubspec.lock`, changes the dependency graph the committed suite resolves against, and
survives a careless `git add -A`. Nothing about a half-day spike justifies that risk.

**Alternatives considered:** (a) a `spike/` directory inside the repo, deleted at the end — same
teardown discipline but one `git add -A` away from being committed, and it would need a
`.gitignore` entry that outlives the spike; (b) a git worktree — isolates the commit but not
`app/pubspec.lock`, since the point is to run the generator against a real Flutter package.
Outside the tree is the only option where forgetting the teardown cannot dirty `main`'s history.

**Consequence, made a task:** the teardown is proven, not asserted — `git status --porcelain`
empty except the intended documentation, and `git diff --exit-code -- app/pubspec.yaml
app/pubspec.lock` exiting 0.

### Decision 3 — the three representative schemas are named here, and the ADR carries them inline

§2 says *"three representative schemas"* and stops. Representativeness is the whole experiment:
three easy schemas make any generator look good. These three are chosen so that between them they
exercise every shape the real 12–15 endpoints can produce **under §2's own zero-polymorphism
rule** — no `oneOf`, no `discriminator`, variance hidden inside an opaque `params`/`payload`.

1. **The item response** — `{itemId, prompt: PromptToken[], keypad}` from `ARCHITECTURE.md`:179,
   **with `options` removed** per `docs/IMPLEMENTATION-PLAN.md`:1693. Exercises: a nested array of
   objects, an enum-valued field, and the response the client reads most often.
2. **The attempt submission and its verdict** — request `{itemId, sessionId, answer, clientTs}`,
   response the verdict. Exercises: a request body, a `date-time`, a client-generated
   `session_id` (`ARCHITECTURE.md`:164), and **the opaque `payload` slot** that §2 makes variance
   hide in — the single most likely place for a generator to emit `dynamic` or `Object?`.
3. **The offline pack manifest** — `{id, playerId, skillId, templateRefs[], packSalt, issuedAt,
   expiresAt}` from `ARCHITECTURE.md`:194-198. Exercises: an array of records inside one field, a
   binary column as base64, an **optional** field (`skillId`) and a **nullable** one
   (`expiresAt`) — optional-vs-nullable fidelity is where generated Dart usually fails
   null-safety, and it is invisible in schemas 1 and 2.

The ADR embeds all three Zod schemas and the resulting OpenAPI document **inline, as fenced
code**. That is what makes the spike reproducible after Decision 2 deletes the scaffold; without
it the ADR is an opinion with no inputs. The embedded document is roughly 150 lines and belongs in
the ADR rather than in `contract/`, which does not exist yet and is `f1-contract-emitter`'s to
create.

### Decision 4 — the spike's variable is the Dart, so the emitter may be bypassed

The chain is *Zod → OpenAPI → Dart*, but the **dependent variable is the Dart output**. Choosing a
Zod-to-OpenAPI emitter is a real decision with its own trade-offs (Zod 4's built-in
`z.toJSONSchema` emits 2020-12, which is 3.1 — and §2 pins **3.0.3**), and making it inside a
half-day box would consume the box and pre-empt `f1-contract-emitter`.

**Chosen:** author the three Zod schemas as the schemas of record; if a zero-friction emitter
targeting 3.0.3 is at hand, use it; otherwise **transcribe them to a 3.0.3 document by hand,
mechanically**. Either way the ADR states which path was taken, because a hand-transcribed
document is a threat to the result's validity — a human transcriber writes a cleaner document than
an emitter would, which flatters the generator. The mitigation is that the document is embedded
(Decision 3) and can be re-checked against a real emitter at F1.

### Decision 5 — the removed options are removed by a command, not by a claim

`dart-dio` and `openapi-generator-cli` need a JVM; `openapi-generator-cli`'s container path needs
Docker. **The check that proves it is `java -version`, not `command -v java`** — macOS ships a stub
at `/usr/bin/java` that makes `command -v java` succeed on a machine with no runtime at all, so the
obvious check reports the opposite of the truth. The ADR records the invocation and its output
(`Unable to locate a Java Runtime`), and the same for `command -v docker`. This costs one line and
stops the next reader from reopening two options on a bad check.

### Decision 6 — *"better"* is a rubric, and a tie goes to hand-written

§2's criterion is asymmetric by construction — *"if the generated Dart … is not better than what
you would write by hand, write it by hand"* — so **the burden of proof is on codegen** and an
inconclusive spike is a decision for the hand-written client, including when the half-day box
expires. Recording that up front is what stops the box from quietly becoming two days.

Reading the generated code answers these, and the ADR answers them one by one:

| Dimension | Why it decides anything |
|---|---|
| `flutter analyze --fatal-infos`, zero infos | The enforced gate (`CLAUDE.md`). Generated code that trips it costs an analyzer exclusion, and excluding a directory from the repo's own gate is a real, permanent cost. |
| Optional vs nullable fidelity | Schema 3's `skillId` / `expiresAt`. `dynamic` or `late` here means every call site pays for the generator's imprecision. |
| The opaque `payload` slot | Schema 2. Does it survive as a typed opaque value or collapse to `Object?`. |
| Byte determinism over two runs | §2 hangs `git diff --exit-code` on it. Not a preference — the gate exists or it does not. |
| Transitive dependency cost, with a DEP-1 audit | Five packages, `build_runner` in every worktree, and cold-build wall time — against a hand-written floor of **zero**, since `dart:io`'s `HttpClient` is in the SDK and `app/pubspec.yaml` ships three runtime dependencies today. DEP-1 requires the network-call audit **before** a dependency is proposed, so the ADR states it for candidates that do not survive too — otherwise a later session re-proposes one from memory with no audit on file. |
| Readability against ~250 hand-written lines | §2's own yardstick, and the one a reviewer will apply in F3. |

**Order matters and is fixed:** the hand-written client for the same three schemas is sketched
**first**, before the generator runs. Writing it afterwards means writing it against the generated
output, which is not the comparison the criterion asks for.

### Decision 7 — the ADR convention is minted here

`docs/adr/0001-dart-api-client.md`: a zero-padded four-digit sequence, a kebab-case subject, one
decision per file, never renumbered. Headings are Nygard's — **Status · Context · Decision ·
Consequences** — plus two this repo earns: **Evidence** (PROC-5 culture: commands and their real
output, never a claim) and **Inputs** (Decision 3's embedded schemas). `Status` for this one is
`Accepted`, dated, naming `f0-dart-client-spike` as the change that produced it.

**Alternative considered:** MADR, which is richer and adds *Considered Options* / *Decision
Outcome* / per-option pros and cons. Rejected as ceremony for a repository whose ADR directory is
empty and whose first entry has exactly two options — but the choice is recorded because ADR 0001
sets the convention for every ADR after it, and picking one by accident is how a directory ends up
with three formats.

### Decision 8 — TDD's red-first ordering does not apply, and `tasks.md` says so out loud

PROC-1 and `openspec/config.yaml` both order tasks so a failing test precedes the code that passes
it. **This change writes no product behaviour, so there is nothing to fail first**, and a token
Dart test asserting that a Markdown file exists would satisfy the letter of the rule while making
the suite worse. `openspec/config.yaml`'s own task rule already allows the alternative — *"a
command with its expected output"* — and every task here uses that form. Stating it in the
artifacts is deliberate: an unexplained absence of tests reads as an oversight to the reviewer,
and this one is a decision.

## Risks / Trade-offs

- **The generator does not run at all** under Dart 3.11.5 / current `build_runner` → that is an
  outcome, and the ADR records it as *availability*, not as a quality judgement. Same decision
  (hand-written), different and weaker reason, and the distinction matters if someone revisits
  this in a year when the package has caught up.
- **A hand-transcribed OpenAPI document flatters the generator** (Decision 4) → mitigated by
  embedding the document in the ADR so F1 can re-run the chain against a real emitter.
- **Three schemas are three schemas** → mitigated by choosing them for shape coverage
  (Decision 3), and bounded honestly: the ADR states what the three do *not* cover — auth flows,
  pagination, and error envelopes — so the decision can be revisited on evidence rather than on
  memory.
- **The teardown is forgotten and `app/pubspec.lock` moves** → Decision 2 puts the scaffold where
  `git` cannot see it, and the teardown task's check is `git diff --exit-code`, not a promise.
- **The determinism finding orphans `ARCHITECTURE.md` §2.** If the generator is not byte-stable,
  or if hand-written wins, §2's *"CI runs the generator and does `git diff --exit-code`"* describes
  a gate that will never exist. Leaving it there means a future session builds a CI job for it.
  **PROC-6 makes the amendment due in the same session**, and it is a task, not a footnote. The
  ADR states plainly whether it amended §2 or merely recorded the finding.
- **The decision is reversible and should say so.** If F3 finds the hand-written client sprawling
  past ~250 lines or the endpoint count past 15, the ADR is superseded by a new ADR rather than
  edited. The threshold is written into `Consequences` so the trigger is checkable instead of a
  matter of taste.
