# The game is for adults

## Why

The project owner decided on 2026-08-29 that AkiMath is available to **adults only**, so that the
product stops carrying the legal weight of a mixed audience. **A sibling change writes the ADR that
records the decision. This change does not take it; it carries it out.**

What the decision removes is one sentence, and that sentence is load-bearing in more places than
anyone has counted. `CLAUDE.md`:7 and `ARCHITECTURE.md`:21–26 both say the audience is adults *and
children can play too*, and both draw the same conclusion from it — **a mixed audience is governed
by its youngest member**, so every protection an under-13 needs is unconditional. That premise is
why `players.age_band` has three values, why the age gate *routes* rather than refuses, why DEP-1's
answer to analytics is a standing no rather than a question, and why `docs/gates/gate-a-childrens-data-consult.md`
asks counsel *"what does a general-audience app that owes child protections have to do"* instead of
a narrower question.

Remove the premise and none of that becomes wrong automatically. Some of it survives on other
grounds, some of it goes, and some of it keeps working while the reason written beside it stops
being true. **Telling those three apart is the whole of this change**, because the third kind is
invisible: nothing goes red, and the repository quietly starts arguing for a product it is not.

Two sentences in `CLAUDE.md` are already the warning. *"Where a comment or a document says 'a
child', ask whether it means the player or specifically the under-13 case."* And
`ARCHITECTURE.md`:26, *"Prose here written before that date often says 'a child' where it means 'a
player'."* Both were written for the 2026-08-17 clarification. This is the second such correction
in twelve days, and the first one is the reason this proposal counts sites instead of grepping for
a word.

## Phase

**Outside `ARCHITECTURE.md` §9**, and `openspec/config.yaml`:51 permits saying so. Every phase from
F0 to F8 is a build phase — scaffolding, core, compositor, app loop, server, features, Rive — and
none of them is a phase for reversing a product premise.

The consequences do land in phases, and naming them is the useful half:

- **F1** — the frozen schema. `players.age_band`'s value set, applied to a live database.
- **F3** — the contract, the server's `link.ts`, the age gate in the app, and two unmerged
  dependents: `f3-store-artifacts` (Data Safety, the privacy manifest) and `f3-deletion-web`,
  whose delta spec carries `req-the-page-reads-as-a-person · A child may read this page`.
- **F7** — the account flow the gate stands in front of.

## What already exists

| What | Where |
|---|---|
| The column and its CHECK | `packages/server/migrations/0001_initial.sql`:57–63 — `CHECK (age_band IN ('under_13', '13_17', 'adult'))` |
| The applied snapshot | `packages/server/schema.sql`:113 |
| The band set, declared | `packages/contract/src/openapi/api-schemas.ts`:152 — `const AGE_BANDS = ["under_13", "13_17", "adult"] as const;` |
| The band set, declared **again** | `packages/server/src/link.ts`:23 — `const BANDS: readonly string[] = ["under_13", "13_17", "adult"];` |
| The emitted enums | `contract/openapi.json` — `components.schemas.Me.properties.ageBand` (:277–281) and `components.schemas.PlayerLink.properties.ageBand` (:357–361), byte-identical, both `required` |
| The only server-side validation | `packages/server/src/link.ts`:70–75 |
| The gate | `app/lib/features/auth/policy/age_gate.dart` — `AgeGateRoute { createAccount, tutorConsent }`, `consentAge = 13`, `bandFor(bornOn:today:)` |
| The screen that asks | `app/lib/features/auth/ui/age_gate_screen.dart` — `'¿CUÁNDO NACISTE?'` |
| The screen an under-13 reaches | `app/lib/features/auth/ui/tutor_consent_screen.dart` — `'Sigue jugando'` |
| The Dart enum | `app/lib/api/me.dart`:12–26 — `AgeBand`, with `fromWire` that throws rather than defaulting |
| The consult | `docs/gates/gate-a-childrens-data-consult.md` — eleven questions to counsel, §2 *"The audience, corrected"* |
| The premise, in the places that seed new work | `CLAUDE.md`:7, `ARCHITECTURE.md`:21–26, `openspec/config.yaml`:18–21, `.claude/conventions/craftsmanship.md`:185–199 (DEP-1) |

## The impact map

Sites fall into **three kinds**, and the third is the one that rots.

- **A — behaviour changes.** Something goes red, and it should.
- **B — the gate stays green and stops meaning what it meant.** A reported count moves, or a sweep
  goes vacuous. This is the dangerous kind, and PROC-10 is the repository's name for it.
- **C — the conclusion still holds and the reason written next to it does not.** Nothing red. The
  largest category by a distance.

### A · Schema — one forward-only migration, no data migration

`0001_initial.sql` **is not edited**, and there are three independent locks saying so:
`src/migrate.ts`:53–60 refuses to start when a recorded checksum moves; CI's `protected-paths`
guards `migrations/**` and `schema.sql`; CI's `integration` job byte-diffs the re-dumped snapshot.
The comment at `0001_initial.sql`:53–54 anticipated exactly this and is worth quoting, because it
makes the migration cheap:

> A CHECK and not an enum: the band set is Gate A's to confirm, and replacing a CHECK is one
> forward-only statement while an enum value can never be removed.

So the change is **`0009_the_only_band_is_adult.sql`** — the next free number; 0001 through 0008 are
on disk and applied — dropping `players_age_band_known` and adding it back over one value, plus
`npm run schema:dump`. Migrations 0002 through 0008 touch the band in no way at all; 0003 mentions
`ageBand` in prose only.

**Is a data migration needed? No, and that is checked rather than assumed.** The consult document's
own status section records the answer: `docs/gates/gate-a-childrens-data-consult.md` §7 states
*"The single `players` row carries the `adult` band."* Q-A2 says the same. Taking the project
owner's account together with that, the live database holds one player row already carrying the
only value that will survive, and two verified Neon Auth accounts that this service cannot reach at
all — identity lives in the provider's `neon_auth` schema and `packages/server` holds no credential
that could touch it (ADR 0002, `src/erasure.ts`).

The census is still task 1.1, because *recorded on 2026-08-26* and *true now* are different claims
and the migration is the wrong place to discover the difference. If a non-adult row is ever found,
**the `ALTER` failing is the correct outcome** — the same argument `f3-players-belong-to-an-account`
D3 made about `NOT NULL` with no backfill, *"the refusal is right"*. Such a row is not rewritten:
`UPDATE players SET age_band = 'adult'` would record an assertion the player never made. It is
erased through the path that already exists, and then the migration runs.

### A · Contract — narrowing, and the verdict is breaking

Two enums, both `["under_13", "13_17", "adult"]`, both on a **required** property, one in a request
schema and one in a response schema:

| Schema | Direction | `required`? | `additionalProperties` |
|---|---|---|---|
| `PlayerLink.ageBand` | request body of `POST /players/link` | yes | `false` |
| `Me.ageBand` | response of `GET /me` and of `POST /players/link` | yes | `false` |

**Narrowing them is breaking, and the request half is what decides it.** The two directions are not
the same question:

- **Narrowing a request enum removes values a client may already be sending.** A shipped device that
  sends `13_17` starts getting a 400 it never got before. That is the textbook breaking change, and
  it is the same *class* `f3-link-carries-the-band` already proved fires here — that change made
  `ageBand` required and `oasdiff` returned `new-required-request-property`, exit 1.
- **Narrowing a response enum delivers a subset of what a client already handles.** Nothing a
  consumer built for three values breaks when it receives one of them. It is *adding* to a response
  enum that breaks a consumer, not removing.

So: **breaking, on the request half alone, and the pull request needs `allow-breaking-contract`.**
Task 1.2 records the actual rule id and exit code against the pinned `oasdiff` 1.29.1 rather than
leaving that as reasoning — the same evidence `f3-link-carries-the-band` D3 produced, and the same
reason: this gate has been wrong before about whether it ran at all.

The asymmetry is also an argument about the column, and it is in `design.md` D2: **removing
`ageBand` outright is breaking on *both* halves**, because dropping a required property from a
response is the response-side break that narrowing an enum is not.

### A · Server — the fourth declaration, and the one with no gate on it

`packages/server/src/link.ts`:23 retypes the band set. It is not imported from
`@akimath/contract`, it is not derived from `contract/openapi.json`, and **no test ties it to
either** — `grep -rn "AGE_BANDS" packages/server/src` returns nothing. The doc comment in
`api-schemas.ts`:145 says the set is *"declared once"*; that is true inside that file and false
across the repository. `link.ts` can drift from the contract and from the CHECK silently, and the
symptom would be a request the contract permits and the pure reader refuses, or worse the reverse.

Everything else on the server passes the value through and decides nothing with it:
`src/players.ts`:14,51 types it as `string` and copies it into the response;
`src/adapters/player-repository.ts`:25,81–87 selects and inserts it;
`src/adapters/http-server.ts`:363 forwards it. **No handler branches on the band**, and
`src/retention.ts` does not read it — retention is unaffected, and that is a finding rather than an
omission.

### A · App — the gate stops routing

`AgeGate.next` is a two-armed router: `under13 → tutorConsent`, everything else → `createAccount`.
Under adults-only there is one arm and a refusal. The chain that carries the band is eight hops long
and every one of them is a site:

`age_gate_screen.dart`:90–91 → `auth_flow.dart`:217 `_resolved` → `auth_flow.dart`:147 `_band` →
`auth_flow.dart`:468–476 `LinkedAccount` → `profile_route.dart`:465–470 `LinkedSession` →
`profile_route.dart`:306–314 → `api_client.dart`:87–105 `linkPlayer` → the wire.

**A second source of the band exists and is easy to miss.** `auth_flow.dart`:427–438
`_bandTheServerAlreadyHas` reads the band off `GET /me` on a sign-in and only falls back to the gate
for `MeNoPlayer()`. A returning player's band comes from the server, not from the gate, so
narrowing the gate alone leaves that path able to produce a band the contract no longer names — the
client would throw `FormatException` out of `AgeBand.fromWire` rather than defaulting, which is the
right failure and still a failure nobody has designed a screen for.

Persisted state is a site too: `app/lib/features/account/data/session_store.dart`:53,123–155 writes
an `'age_band'` key to `shared_preferences`, and `session.dart`:97–100 asserts in prose that a
stored value *"can only ever be `13_17` or `adult`"* — a sentence this decision falsifies, on a
device that may already hold the other value.

`tutor_consent_screen.dart` becomes dead or becomes the refusal, and that is question 2 below.

### B · The gates that stay green and stop meaning what they meant

Four, and they are the reason this section exists.

1. **`packages/contract/test/openapi.test.ts`:349–366 goes vacuous.** The sweep that finds band
   enums detects them by the literal `"under_13"` at line 353. Collapse the set and `bandEnums`
   comes back **empty**, and the assertion fails reading *"the band schemas vanished from the
   document"* rather than *"the set changed"*. It fails rather than passing, which is luck: a
   differently written detector would have gone quietly green over nothing.
2. **`packages/server/test/link-request.test.ts`:135–152 keeps passing and reports a smaller
   number.** It reads every offered enum value from the committed contract and inserts each into the
   real table, printing `N offered band(s) → N accepted`. Three becomes one. It has a
   `expect(offered.length).toBeGreaterThan(0)` guard, so it cannot go fully vacuous — the guard is
   doing real work now and should be said out loud.
3. **The screen registry counts move.** `app/test/design/screen_registry.dart` registers `'age gate'`
   (:331–340) and `'tutor consent'` (:341–344). Six suites read that list —
   `screen_overflow_test`, `touch_target_test`, `no_blurred_shadow_test`,
   `quiet_while_you_solve_test`, `screen_text_style_test` and the registry's own — and they report
   totals (today 85 screens, 425 presses). Removing or replacing a screen moves those totals, and
   nothing enumerates expected filenames, so **deleting `tutor_consent_screen.dart` trips no
   architecture test at all**.
4. **`app/test/architecture/pure_boundary_test.dart` counts `features/*/policy/` at 47 files.**
   `age_gate.dart` lives there. Turning a router into a refusal predicate keeps it pure and moves
   nothing; replacing it with something that reads a clock or a store would not, and the gate is
   what says so.

### A · The tests that go red

Not a burden — the list *is* the specification of how much of the product assumed three bands.

**TypeScript.** `packages/server/test/players.test.ts`:41 (iterates all three);
`link.test.ts`:15,24,77–81,122 (:122 asserts the *error message text* `"under_13, 13_17, adult"`),
:131; `link-player.test.ts`:57,63,80–81,180; `get-me.test.ts`:26,31,96,111;
`offline-packs.test.ts`:36 seeds `'under_13'` directly and the whole suite dies at setup;
`packages/contract/test/openapi.test.ts`:373. Roughly twenty-five further sites use `'adult'` as
filler and compile unchanged. Two tests get *better*: `link.test.ts`:70's list of rejected bands
gains two true members, and `players.test.ts`:32–35 still rejects `"13_15"` for the same reason.

**Dart.** `app/test/features/auth/policy/age_gate_test.dart` — the whole file, premise and all.
`app/test/features/preferences/link_on_session_test.dart`:81 is **semantically dead rather than a
fixture edit**: its scenario is that an `under13` band travels verbatim to the link request, and
that scenario cannot occur. `contract_parity_test.dart`:87–96 pins the enum by value *and order*
against `../contract/openapi.json`, so nothing in `app/` can move before the contract does;
:463–465 pins `PlayerLink.required == {playerId, ageBand}`. Then `me_test.dart`:9,32–41;
`session_store_test.dart`:56–75,120–125; `api_client_test.dart`:655–690,708;
`sign_in_door_test.dart`:193,196,254,288; `session_survives_a_relaunch_test.dart`:13,131,243;
`session_test.dart`:76–82; `session_restore_test.dart`:9,41; `auth_flow_test.dart`:157,228,443; and
`integration_test/account_tour_test.dart`:60–82, whose case is named *"a child reaches consent, and
no path from there reaches the form"*.

**`packages/core` is untouched.** Zero band references; its fifteen "child" hits are prose meaning
*the player*, plus Node's `child_process`.

### A · The frozen specs

Four requirements name the band, and all four are deltas in this change. None of them needs its
**title** changed, which matters: `openspec` matches a `MODIFIED` block on the whole header, so a
retitle silently creates a duplicate requirement instead of editing one. Measured, not assumed —
see `design.md` D7.

| Capability | Requirement | Why |
|---|---|---|
| `data-schema` | `req-player-shape` | names the three values in its `SHALL` |
| `api-contract` | `req-the-link-request-can-create-the-row` | *"A band the database would refuse"*, *"One band set, not two"* |
| `api-client` | `req-the-model-is-the-frozen-schema` | *"The bands, in order"*, and *"A band nobody decided"* whose rationale the decision inverts |
| `api-transport` | `req-refused-before-the-database` | *"**WHEN** `ageBand` is outside the three"* |

`req-refused-before-the-database` does **not** become vacuous and is not deleted: *anything that is
not `adult` is a 400* is still a live, testable claim, and it is the claim that keeps a hand-crafted
request out of the table.

### C · The prose whose conclusion holds and whose reason does not

Ordered by how much damage a stale sentence does.

1. **`openspec/config.yaml`:18–21 — the highest-leverage line in the repository.** It is read into
   **every** future proposal, and it says *"Audience includes children under 13. That is an
   architectural constraint, not a footnote: no third-party SDK that collects data, no ads, no
   external analytics."* Left alone, every plan written after this change starts from a product
   that no longer exists — which is precisely the failure that block already records about itself:
   *"This block said the opposite until 2026-08-26… and every plan written against it started from
   a repository that had not existed for weeks."* PROC-7 makes this a paired edit with
   `craftsmanship.md`: *"Edit both in the same commit, or neither."*
2. **`CLAUDE.md`:7–21 and `ARCHITECTURE.md`:21–26** — the two canonical statements. The 2026-08-17
   clarification is *amended*, not deleted; the record of what the product used to be is what makes
   the third correction cheap.
3. **`docs/gates/gate-a-childrens-data-consult.md`** — a document addressed to an external lawyer
   whose §2 heading is *"The audience, corrected"* and whose §3 question is *"what does a
   general-audience app that owes child protections have to do"*. That is now the wrong question,
   and Q-A9 already flags its own premise as unstable. This is not a rewrite an agent performs; it
   is question 4 below.
4. **`.claude/conventions/craftsmanship.md`:185–199, DEP-1.** Only the *second sentence* is
   audience-derived. See "The dependency constraint" below — it gets its own section because it is
   where the decision actually bites.
5. **ADR 0002** — audience-load-bearing at :16, :36, :40–47, :54, :66, :118–120, :133. Its
   *decision* survives intact (unlinked play is offline; linking is the first server contact) and
   the reason moves from *"it never touches a child's device"* to something that does not name a
   child. An ADR is a record, so it is amended in place the way 0002 already carries a 2026-08-19
   amendment, never rewritten.
6. **Four agent definitions** carry the premise in their operating instructions:
   `craftsman-engineer.md`:9, `craftsman-lead.md`:221–222, `craftsman-reviewer.md`:143,
   `craftsman-bug-hunter.md`:20 and its `description` frontmatter. `clean-coder.md` is clean.
7. **Two invariants whose rule survives and whose justification does not.**
   `app/test/design/touch_target_test.dart`:16–17 grounds the 48 px floor in *"a child's aim is
   worse than an adult's"*; `screen_registry.dart`:74 grounds `textScaler` 1.3 in *"the text size a
   child's device arrives with"*. Both floors stand on their own — 48 dp is Material's own minimum
   and 44 pt Apple's, and adults are the population that most raises system text size. **The rules
   do not move; the sentences beside them do.** Anyone tempted to relax a threshold because its
   stated reason went away should read this line first.
8. **Comments in shipping code**, all category C: `app/lib/api/me.dart`:9–11,
   `features/account/policy/session.dart`:31–33 and :97–100,
   `features/auth/ui/auth_flow.dart`:58–66, `design/icons/spec/icon_paths.dart`:18,
   `design/tokens/brand_typography.dart`:8, `features/home/data/day_log_store.dart`:8,
   `features/home/policy/day_log.dart`:7,19, `app/pubspec.yaml`:104–105,
   `packages/server/src/retention.ts`:23,52, `packages/server/test/dependency-allowlist.test.ts`:29–32,
   `packages/contract/src/openapi/api-schemas.ts`:157–166 — the last being the strongest written
   argument *against* this collapse, which is a reason to read it before landing rather than a
   reason not to.
9. **`docs/IMPLEMENTATION-PLAN.md`** — `req-age-gate` at :2122–2144, the routing decision at
   :1553–1560, D13 at :2560 and D21 at :2568, both of which cite **`CLAUDE.md`:7 by line number**
   as their load-bearing constraint. Both survive on independent grounds and both need their
   reasoning restated. **A discrepancy found on the way past**: the plan says the band set is
   `{under_13, 13_17, 18_plus}` (:2164, :2947) and the live CHECK says `adult`. The plan has been
   stale since the 2026-08-17 freeze; it is fixed here because this change is already in the file.
10. **`f3-deletion-web`, unmerged**, carries `req-the-page-reads-as-a-person · A child may read
    this page` in its delta spec plus four proposal sites. Not edited from here — a change's plan
    is its own — but its author has to know.

**A gap, found and not filled by this change**: no document anywhere states the app-store **age
rating**. An adults-only product has one to declare, and there is no passage to amend.

## The dependency constraint

This is where the decision actually bites, and **the plan neither keeps nor drops the rule.**

`CLAUDE.md` justifies *no third-party SDK that collects data, no ads, no external analytics* with
*"a mixed audience is governed by its youngest member, so every protection an under-13 needs is
**unconditional**"*. This decision removes that premise, and with it the word that did the work.
DEP-1 has always been a per-dependency human gate; what the mixed audience did was pre-decide the
answer for one category. **So the narrow question for a human is: does DEP-1 keep its standing "no"
for analytics, ads, attribution and crash reporting, or does that category go back to being asked
case by case?**

**Three supports survive the premise, and they are not equally strong.**

- `packages/core` has **no `dependencies` key at all**. That is an architectural property of a pure
  rederivation machine, not a child protection, and nothing here touches it.
- The offline model needs no telemetry to function. ADR 0002 leaves an unlinked device holding no
  credential it could report with, and the pack replays with no network by design.
- The four allowlist tests are already written and already bite. Keeping them costs nothing.

What relaxing would **buy**: crash reporting, product analytics, an ads path to revenue.

What relaxing would **cost**, measured against what is on disk rather than guessed. `app/`'s
transitive runtime closure is **28 packages**, all Flutter-team or Dart-team, and the only network
API in it belongs to the SDK itself. One crash reporter is not an increment on that — Firebase
Crashlytics brings `firebase_core` plus a native SDK on both platforms, and the precedent already
recorded here is `pino`, turned down for **14 transitive packages** against a floor of zero. Each
also opens a network egress path the app does not have today, which lands on two artifacts that do
not exist yet: the Data Safety declaration (`f3-store-artifacts`) and the aviso de privacidad
(`f3-deletion-web` Q-A10). And adults' data is still personal data under the law the product ships
into; whether the analysis changes is a question for whoever owns Gate A, not for this proposal.

**Recommendation, argued in `design.md` D6 and decided by a human**: keep the rule, restate the
reason, and record that the standing "no" is now a *decision that can be revisited per dependency*
rather than an invariant. Nothing on the roadmap has asked for a dependency that needs it relaxed,
so this costs nothing today and stops the repository defending it with an argument that is no longer
available.

## What changes

> **AMENDED 2026-08-29 — the schema and contract half of this list is overruled.** ADR 0004's
> amendment §3 leaves the `age_band` `CHECK` exactly as it is: no migration `0009`, no collapse of
> `AGE_BANDS`, no re-emitted `contract/openapi.json`, and neither label on the pull request. The
> reason is the one this proposal's own impact map measured — one `INSERT` writes the band, nothing
> `UPDATE`s it, and under Reading A a refused minor never links, so `under_13` and `13_17` go dead
> by construction — plus one this proposal did not weigh: narrowing the set would delete the only
> vocabulary a recorded refusal could ever use, which is still an open question. **The rest of the
> list stands**, and section 2's de-duplication of `link.ts`:23 never depended on the narrowing.
> The costing below is left verbatim; a recommendation that lost is still the record of what it
> would have cost.

- **`0009_the_only_band_is_adult.sql`** — one forward-only migration replacing the CHECK. No
  backfill, no data migration, no edit to `0001`.
- **`AGE_BANDS` collapses to `["adult"]`** in `packages/contract`, and `contract/openapi.json` is
  re-emitted. Breaking; the pull request carries `allow-breaking-contract`.
- **`packages/server/src/link.ts` stops retyping the set** and derives it from `@akimath/contract`,
  with a test tying the two — so the chain runs *contract source → `openapi.json` → the CHECK* with
  no unguarded copy in it. **This lands before the narrowing**, so the narrowing is one edit rather
  than four.
- **The vacuity guards** on the two sweeps in section B, because a set of one is exactly where a
  sweep keyed on a literal goes quiet.
- **The gate refuses instead of routing**, in whichever of the two shapes question 2 settles.
- **The prose**, in the ten places section C names, in one commit per document so the diff is
  readable.
- **`docs/decisions/OPEN.md` gains an entry** for DEP-1's standing no.

## What a human has to do

Five things, none of which a session can do. They are tasks 0.1 to 0.5 and **nothing below task 0
starts until 0.1 is answered**, because 0.1 changes what the contract half should say.

1. **Decide where the refusal happens** — at link time, or at app open. Costed in `design.md` D3.
2. **Design the refusal screen and write its es-MX copy.** No document draws it, and this proposal
   deliberately invents no Spanish.
3. **Answer DEP-1's standing "no"**, recorded in `docs/decisions/OPEN.md`.
4. **Re-scope the Gate A consult.** Its question to counsel is now wrong twice over.
5. **Label the pull request `allow-protected-edit` and `allow-breaking-contract`, and run
   `npm run migrate` against Neon after it merges.** Recording `0009` in `schema_migrations` makes
   that file's checksum load-bearing for ever, which is a production change and a person's to make
   — the same line `f3-players-belong-to-an-account` drew.

## Non-goals

- **The ADR.** A sibling change writes the decision itself. This plan cites it and does not restate
  it; if the two disagree, the ADR wins and this plan is corrected.
- **Deciding anything in "What a human has to do".** Options are costed. None is chosen here except
  where a recommendation is labelled as one.
- **Inventing es-MX copy for the refusal**, or any other screen. LANG-1, and the design project is
  read-only from a session.
- **Editing `f3-deletion-web` or `decide-the-keypad-offers-what-it-accepts`.** A change's plan
  belongs to that change.
- **Deleting the record of the old audience.** `CLAUDE.md`, `ARCHITECTURE.md` §1 and the consult
  are *amended*. A third correction is cheap only because the first two are still legible.
- **Deleting the Neon Auth accounts.** Out of reach rather than deferred: identity is the
  provider's and this service holds no credential that could remove it.
- **Retention, erasure, rating, packs and the offline loop.** Swept and confirmed untouched.
  `src/retention.ts` does not read the band.
- **Relaxing any threshold whose stated reason this decision removes** — the 48 px floor and
  `textScaler` 1.3 stay exactly where they are.
