# Tasks — f0-dart-client-spike

**No task here writes product code**, and none writes a test: this change produces a decision, not
behaviour, so PROC-1's red-first ordering has nothing to order (`design.md`, Decision 8). Every
task below therefore names its check in the third form `openspec/config.yaml` allows — *a command
with its expected output*.

**Only tasks 6.1, 7.1 and 7.2 produce commits.** Groups 1 to 5 run entirely outside the working
tree (`design.md`, Decision 2) and leave no diff; group 8 proves that.

**Timebox: half a day** (`ARCHITECTURE.md` §9). If it expires before group 5, stop and write the
ADR anyway — an expired box is a decision for the hand-written client (`design.md`, Decision 6),
and the ADR records it as *timebox*, not as a measurement.

## 1. Preconditions

- [x] 1.1 Record the green baseline before touching anything: `cd app && flutter analyze --fatal-infos && flutter test`, then `cd packages/server && npm run verify` → check: analyzer clean, **34** Flutter tests and **3** TypeScript tests passing; paste the counts into the ADR's Evidence section (PROC-5, Tier 1).
- [x] 1.2 Prove the working tree is clean where it matters before the spike starts → check: `git status --porcelain -- app packages docs contract ARCHITECTURE.md CLAUDE.md` prints nothing; scope it to those paths rather than running it bare, because `openspec/changes/` is untracked and carries other in-flight changes, so a bare run collapses to one uninformative line.
- [x] 1.3 Prove the JVM and Docker options are closed by running the checks, not by repeating the claim: `java -version` and `command -v docker` → check: `java -version` prints `Unable to locate a Java Runtime` (`command -v java` succeeds on the macOS stub and is **not** the check — `design.md`, Decision 5) and `command -v docker` prints nothing; capture both outputs verbatim for the ADR.
- [x] 1.4 Create the throwaway workspace outside the working tree at `$TMPDIR/akimath-spike-a/` with two sub-packages, `schemas/` (Node) and `client/` (a bare Flutter/Dart package) → check: `realpath $TMPDIR/akimath-spike-a` does not start with the repository root — this is the check the whole isolation rests on, so run it before installing anything.

## 2. The inputs

- [x] 2.1 Author the three representative Zod schemas named in `design.md`, Decision 3 — item response (`options` removed per `docs/IMPLEMENTATION-PLAN.md`:1693), attempt submission with its opaque `payload` and `sessionId`, and the offline pack manifest with its optional `skillId` and nullable `expiresAt` → check: `npx tsc --noEmit` clean in `$TMPDIR/akimath-spike-a/schemas/`.
- [x] 2.2 Produce the OpenAPI **3.0.3** document from those three schemas, by emitter if one targeting 3.0.3 is at hand and otherwise by mechanical hand transcription (`design.md`, Decision 4) → check: the document's `openapi` field reads `3.0.3` and a grep for `oneOf`, `anyOf` and `discriminator` returns nothing (`ARCHITECTURE.md` §2, zero response polymorphism); record which of the two paths was taken.

## 3. The hand-written baseline — before the generator, not after

- [x] 3.1 Write the hand-written Dart client for those same three schemas in `$TMPDIR/akimath-spike-a/client/`, using `dart:io`/`package:http` shapes only and holding no decisions (PURE-2) → check: `dart analyze --fatal-infos` clean, and `wc -l` recorded against §2's ~250-line yardstick for 12–15 endpoints.
- [x] 3.2 Freeze the baseline before looking at any generated output → check: record a digest of the hand-written tree now — `find . -type f | sort | xargs shasum | shasum` — and re-verify **that recorded digest** at task 4.4; a copy compared against itself would pass even if the original were rewritten after reading the generated code, and writing the baseline against the generator's output is not the comparison `ARCHITECTURE.md` §2 asks for (`design.md`, Decision 6).

## 4. The generator

- [x] 4.1 Install `swagger_dart_code_generator` and `build_runner` in `$TMPDIR/akimath-spike-a/client/` only → check: `pwd` reads `$TMPDIR/akimath-spike-a/client` at the moment `dart pub add` runs, and that directory's `pubspec.yaml` is the one that gained the entries; `git diff` over `app/` would pass here whether or not the spike ran at all, so the real collateral-damage check is task 8.2's, not this one (`design.md`, Decision 2).
- [x] 4.2 Run the generator once against the 3.0.3 document → check: `dart run build_runner build --delete-conflicting-outputs` exits 0; if it cannot run at all under Dart 3.11.5, stop the group and record the outcome as **availability**, not as a quality judgement (`design.md`, Risks).
- [x] 4.3 Run the generator a second time from a clean output directory and compare bytes → check: `diff -r` (or `shasum` over the sorted file list) between the two output trees; **empty means the `git diff --exit-code` gate in `ARCHITECTURE.md` §2 is real, non-empty means it does not exist** — record which, with the command's literal output.
- [x] 4.4 **Read the generated code** against the rubric in `design.md`, Decision 6 → check: `dart analyze --fatal-infos` over the generated directory with its info count recorded, task 3.2's digest re-verified unchanged, plus a written finding per row — optional-vs-nullable fidelity on `skillId`/`expiresAt`, whether the opaque `payload` survived typed or collapsed to `Object?`, and the generated line count against task 3.1's.
- [x] 4.5 Audit every dependency the generated path drags in, per DEP-1 → check: `dart pub deps --style=compact` in the spike client, and one written line per direct dependency stating what network calls it makes at build time and at run time; the audit goes in the ADR even for the option that loses (`proposal.md`, Impact).

## 5. The judgement

- [x] 5.1 Fill the rubric table from `design.md`, Decision 6 with the measured values and reach the verdict, remembering the criterion is asymmetric — a tie, an inconclusive result or an expired timebox all decide for the hand-written client → check: every row of the table has a measured value or an explicit `not measured, and why`, and the verdict names which rows carried it.

## 6. The ADR — commit 1

- [x] 6.1 Write `docs/adr/0001-dart-api-client.md` in the format `design.md`, Decision 7 mints — Status · Context · Decision · Consequences · Evidence · Inputs — with the verdict, the two-run byte comparison, the task 1.1 counts, the task 1.3 command outputs, the DEP-1 audit, the three Zod schemas and the 3.0.3 document embedded inline, the three shapes the schemas do **not** cover (auth, pagination, error envelopes), and the supersede threshold that makes the decision reversible on evidence → check: `docs/adr/0001-dart-api-client.md` exists, its `Status` line reads `Accepted` with today's date and names `f0-dart-client-spike`, and a reader who deletes `$TMPDIR/akimath-spike-a/` can still reproduce the chain from the file alone.

## 7. Propagation — commit 2, same session

- [x] 7.1 Rewrite `CLAUDE.md`'s **Open decision** section to state the answer and link the ADR → check: `grep -n 'fork in the road' CLAUDE.md` returns nothing and the section names `docs/adr/0001-dart-api-client.md`; an open decision left open after it was decided is what makes the next session redo this work (PROC-6).
- [x] 7.2 Amend `ARCHITECTURE.md` §2 **only if the evidence contradicts it** — the *"CI runs the generator and does `git diff --exit-code`"* clause is dead if task 4.3 found non-determinism or if hand-written won, and the option space narrows either way → check: `ARCHITECTURE.md`:121-138 contains no claim task 4.3 or task 5.1 disproved, and the ADR states in one line whether it amended §2 or only recorded the finding (PROC-6).

## 8. Teardown and close-out

- [x] 8.1 Delete the throwaway workspace → check: `rm -rf $TMPDIR/akimath-spike-a` then `test ! -d $TMPDIR/akimath-spike-a`.
- [x] 8.2 Prove the repository took no collateral damage → check: `git diff --exit-code -- app packages contract` exits 0, and `git status --porcelain -- app packages docs contract ARCHITECTURE.md CLAUDE.md` lists **only** `docs/adr/0001-dart-api-client.md` plus whichever of `CLAUDE.md` and `ARCHITECTURE.md` tasks 7.1 and 7.2 amended — nothing under `app/`, `packages/` or `contract/`. Keep the path scope: a bare `git status` is uninformative here because `openspec/changes/` is untracked and holds other in-flight changes.
- [x] 8.3 Re-run the committed suite and state the evidence tier reached → check: `cd app && flutter analyze --fatal-infos && flutter test` and `cd packages/server && npm run verify` return the same numbers as task 1.1 (34 and 3); state plainly that this change reaches **no tier** — Tier 1 is unchanged rather than passed, Tier 1b has no logic to falsify and Tier 2 has nothing to exercise (PROC-5).
