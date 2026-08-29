# 4. The game is for adults, and the age gate stops routing and starts refusing

**Status:** Accepted — 2026-08-29, decided by Ervin. **Amends `ARCHITECTURE.md` §1's audience
clarification of 2026-08-17**, which this reverses. It supersedes no ADR: 0002's decision and its
whole argument survive intact, for a reason §*Consequences* states rather than assumes.

This record does not relitigate the decision. It states it, then does the three things a decision
of this shape is dangerous without: it separates what the decision removes from what it leaves
standing, it costs the change against the files rather than estimating it, and it puts back to the
human the four questions the decision does not answer by itself.

---

## Context

`ARCHITECTURE.md` §1 has carried a block quote since 2026-08-17:

> **Audience, clarified 2026-08-17.** The product is for **adults**, and children can play it too.
> Every constraint in this document that exists "because children" still holds without exception — a
> mixed audience is governed by its youngest member […] `players.age_band` is the routing decision
> between the two populations rather than a compliance footnote.

**That is the sentence this decision reverses, and it is worth being exact about where it lives**,
because two different decisions have been merged under one label. `CLAUDE.md`'s opening reads
*"The audience is adults, and children can play too (Mexico and Spanish-speaking LatAm, decision
#1; clarified 2026-08-17)"*, which staples the audience clarification to `ARCHITECTURE.md` §11's
**decision #1**. They are not the same thing:

- **§11 decision #1 is about markets** — *"Mexico + Spanish-speaking LatAm […] No US launch"* — and
  it is **untouched**. Its parenthetical, *"COPPA-ready by construction […] without building
  verifiable parental consent"*, does not become wrong; it becomes easier to satisfy.
- **The audience statement is the §1 block quote**, dated 2026-08-17 and belonging to no numbered
  decision. It is the only thing reversed here.

Anyone reading "decision #1 is reversed" would go to §11 and reverse the markets. It is not.

### The decision, and the motive as stated

**Ervin, 2026-08-29: AkiMath will be available to adults only.** The stated motive is to stop
carrying the legal weight of a mixed audience — one product owing, unconditionally and in advance
of any revenue, every protection an under-13 is owed, on the strength of a governing principle
(*a mixed audience is governed by its youngest member*) that had no way to become cheaper as the
product grew.

The motive is recorded, not argued with. What follows is what it costs and what it does not buy.

---

## Decision

**AkiMath is a product for adults. Nobody under 18 is an intended user of it.**

`ARCHITECTURE.md` §1's block quote is amended by a pointer to this file, and the *"children can
play it too"* half of it stops being true by intent. `players.age_band` stops being the routing
decision between two populations, because after this there is only one population.

### 1 · What this removes

The **children's-data regime**, and only that:

- **Parental or guardian consent.** No consent flow, no consenting adult's email address, no
  consent-evidence columns. Gate A's Q-A3 — *"the question with the largest engineering
  consequence, because the answer becomes database columns"* — has no answer to wait for, because
  there is nothing left for the columns to hold. Nothing was ever guessed into them; they are now
  never built.
- **The under-13 branch of the age gate**, and the `13_17` branch with it (§3 below).
- **Most of Gate A**, but not all of it, and not on this document's authority (§*Consequences*).
- **The "governed by its youngest member" premise**, which is load-bearing in more places than the
  age gate and is the reason §4 of *Consequences* exists.

### 2 · What this does *not* remove — and an ADR that let this be inferred would be worse than none

**Adults have data-protection rights. Personal data of an adult is still personal data under
Mexico's LFPDPPP**, and every obligation in Gate A that does not turn on the data subject's age
survives this decision unchanged. Concretely, the service still holds all of this:

| Datum | Held by | Survives this decision |
|---|---|---|
| Email address, password hash, account display name | the identity provider, in our own database | **yes** |
| Session IP address and user-agent, one row per sign-in | the identity provider, recorded automatically and not configurable | **yes** — and see below |
| `player_id`, `age_band`, `attempts`, `user_skills`, `diag_events`, `offline_packs` | our own tables | **yes** |

So, plainly, and each one is an obligation rather than a nicety:

- **The privacy notice and the terms are still owed** (Gate A Q-A10), still in Mexican Spanish,
  still describing this inventory. What changes is that no child-facing version of the notice is
  needed. The notice does not become optional; it becomes shorter.
- **The deletion path is still owed** and still incomplete. `DELETE /me` erases the `players` row
  and everything referencing it, and **does not erase the identity-provider account** — the email,
  the password hash and the display name survive it. That gap was the sharpest edge in Gate A and
  it is exactly as sharp today; the data subject being an adult changes nothing about it. The
  public deletion page that works without installing the app is still unbuilt (`f3-deletion-web`).
- **The retention figures still stand and still have to be published.** 400 days for `attempts`,
  30 days for `diag_events`, in `src/retention.ts`, enforced by a job that runs nightly. Gate A's
  Q-A7 asked whether those periods are defensible *for children's data*; the question narrows to
  whether they are defensible for an adult's, which is a different question with the same shape and
  is not self-answering.
- **The session IP and user-agent problem gets worse, not better.** ADR 0002's mitigation was
  structural: *"a device that resolves to the under-13 band never obtains a session at all"*, so no
  under-13 IP was ever recorded. That protection is unchanged and now covers every minor rather
  than only under-13s. But the datum itself was never protected by it for the population that
  *does* link. Gate A recorded it as **the one datum with no retention period of ours** — our
  retention job does not touch those rows, and whether the provider deletes or merely invalidates a
  session row after seven days *"we have not verified which"*. Every one of those sessions belongs
  to an adult already. This decision does not touch that question; it removes the framing in which
  somebody might have thought it was a children's question.
- **The processor questions are unchanged** (Q-A8): a hosted database in the United States or the
  European Union, an identity provider inside it, and a transactional email provider still
  unchosen. The cross-border transfer question does not care how old the data subject is.

**The one-line version, because it is the sentence this record exists to prevent being misread:
the children's-data regime is gone; data protection is not.**

### 3 · The age gate changes job — this is the real product consequence

Today the gate **routes**. `AgeGate.next()` sends `under_13` to the tutor-consent screen and sends
both `13_17` and `adult` to the account form, and the destination set is closed by a test so a
third cannot appear. After this decision there is nothing to route *into*: the tutor-consent flow
is the entrance to a consent machinery that will not be built. So the gate **refuses**.

Two things follow that are easy to miss.

**`13_17` gets an account today.** This is not only a copy change and not only a change for
under-13s. A sixteen-year-old who declares their date of birth on the age gate today reaches
`1.2 Crear cuenta`, creates an account, links a player and syncs. After this decision they do not.
That is live behaviour changing for a band that is currently served.

**"Adults only" has two readings, and the code today can only implement one of them.** The gate is
mounted in exactly one place — `profile_route.dart:452` puts `AuthFlow` up, and `AuthFlow` puts
`AgeGateScreen` in front of the account form. Nothing else in the app asks anyone's age. A player
who never taps the sign-in door is never asked, and plays the bundled pack offline for ever, which
is ADR 0002's design and is unchanged by anything here. So:

- **Reading A — no minor gets an account.** The gate refuses instead of routing; unlinked offline
  play is untouched. Buildable now: one `switch` arm, one constant, one screen's copy.
- **Reading B — no minor plays at all.** That needs a gate in front of `FirstRunGate`, before any
  content is drawn, and a screen that turns somebody away from the whole product. Nothing of the
  kind is designed, in this repository or in the design project.

**This ADR does not choose between them.** It records that the code implements A by default —
because A is where the only age question in the app already stands — and puts B to the human in
§*Open*.

> **Amended 2026-08-29 — the human chose Reading A.** See "Amendment: the answers" at the end of
> this record. The fork is settled; the refusal screen it needs is not.

**What an under-18 sees is genuinely open.** No design document draws a refusal, `TutorConsentScreen`'s copy
(*"Para crear una cuenta necesitamos el permiso de tu mamá, tu papá o tu tutor. Mientras tanto tus
retos se guardan en este teléfono y nada se envía."*) is a promise of a later account and would
become a lie, and a refusal is a different kind of screen from a deferral. Naming it as open is the
honest answer; inventing the screen here would be this document deciding a product question it was
not asked to decide.

### 4 · A self-declared date is a legal posture, not a technical barrier

Stated flatly, because after this decision the age gate is the only thing standing between a minor
and the product, and it is worth nobody believing it is a wall.

The gate asks for a date of birth in a neutral field, reduces it to a band **on the phone**, and
discards the date. A player who wants an account and is fifteen types a different year. There is no
verification of any kind: no document, no payment instrument, no platform signal, no heuristic.
Gate A already conceded this in Q-A4 and asked counsel whether it was adequate *as assurance for
consent*; the question survives in a changed form (§*Consequences*), but the mechanism does not
improve by being asked to do a different job.

**What the gate is worth is that the question is asked**, in a neutral form that does not invite the
unlocking answer, and that the refusal happens before any account exists. That is a posture, and a
posture is a real thing — it is the difference between a product that turns minors away and one
that never asks. It is not an enforcement mechanism and should never be described as one.

**One correction to the obvious next sentence.** It is tempting to say the gate's value is that it
is *asked and recorded*. It is asked. **It is not recorded** — and after this decision it is
recorded even less than before. The date is discarded on the device; the band travels only inside
`POST /players/link`; a refused player never links, so no row is written anywhere, on the device or
on the server. Today a refused under-13 leaves no trace of the refusal in any system. Whether a
refusal should be recorded, and where, is a genuine question with an unpleasant answer attached:
recording it means storing a declaration about a minor that we do not store today, on a device that
currently holds nothing of the kind. It is in §*Open*, unanswered.

---

## Consequences

### 1 · The cost, measured against the files

Every figure below is produced by a command in *Evidence*. The set of bands is stated in **six**
places, four of them hand-written and two generated:

| # | Site | Hand-written? |
|---|---|---|
| 1 | `packages/server/migrations/0001_initial.sql:59-61` — the `players_age_band_known` CHECK | yes, and **frozen** |
| 2 | `packages/server/schema.sql:110,113` — the committed snapshot | generated by `npm run schema:dump` |
| 3 | `packages/server/src/link.ts:23` — `BANDS`, a local literal | yes |
| 4 | `packages/contract/src/openapi/api-schemas.ts:152` — `AGE_BANDS`, feeding `Me` and `PlayerLink` | yes |
| 5 | `contract/openapi.json:278,358` — emitted, twice | generated by `npm run emit` |
| 6 | `app/lib/api/me.dart:12-15` — the `AgeBand` enum | yes |

**24 files in the product tree name `under_13` or `13_17`** — 8 outside tests and 16 test files.

**There are two options, and the cheap one is not a compromise.** The band is written by exactly one
statement, `INSERT INTO players` at `player-repository.ts:84`, reached from exactly one call site,
`http-server.ts:361`, on the `POST /players/link` path. **No statement anywhere UPDATEs
`age_band`.** Under adults-only a refused minor never links, so **no row can ever again carry
`under_13` or `13_17`** — the values go dead by construction, whether or not anyone deletes them.

| | **Leave the CHECK as it is** | **Narrow it to `('adult')`** |
|---|---|---|
| forward-only migration | none | **0009**, new; `0001` stays verbatim |
| `schema.sql` | untouched | regenerated |
| `allow-protected-edit` label | not needed | **needed** — `ci.yml`'s `protected-paths` diffs `packages/server/migrations/**` and `schema.sql`, and `git diff --name-only` sees an added file |
| `AGE_BANDS`, `BANDS`, `AgeBand` | untouched | three edits |
| `contract/openapi.json` | unchanged | re-emitted; `ageBand` narrows in `Me` **and in `PlayerLink`, which is a request body** |
| `allow-breaking-contract` label | not needed | **expected to be needed** — removing an enum value from a *request* property is the class oasdiff reports at ERR. `ci.yml:516` runs `oasdiff breaking … --fail-on ERR`; the label at `:520` is the answer. *The mechanism is verified; the specific classification is an expectation, not a run.* |
| the 16 test files | untouched | edited |
| the live row | valid — it is `adult` | **still valid** — it is `adult` |
| what actually changes behaviour | `AgeGate.next()`'s switch, `AgeGate.consentAge`, one screen's copy | the same, plus everything above |

**The expensive option buys nothing the cheap one does not, and it destroys something.** Narrowing
the CHECK removes the only vocabulary in which a declared band could ever be recorded — which is
precisely §3's open question about recording a refusal. Deleting the values forecloses it.

One correction to Gate A while it is in view: Q-A2 warns that *"a change to the set also means
moving that row — a cost, but a small and knowable one."* For **this** change it does not. The one
live row carries `adult` and survives either option untouched.

**The behavioural change itself is small, and that is worth saying plainly**: `AgeGate.next()` is
exhaustive over `AgeBand`, so redirecting `13_17` is a switch arm and the compiler finds every
caller. `AgeGate.consentAge = 13` is one constant, named for exactly this reason. The screen an
under-18 lands on is the part that does not exist.

### 2 · Gate A — narrowed, not closed. My reading, and it is the human's call

Gate A's fourth tripwire is met and stays met: the server holds a real person's row, and this
decision does not un-hold it. The document's eleven questions were framed for an app that owes
child protections; most of that framing dies. What is left is a **residual adult-data consult**,
which is smaller than the current brief and is not nothing.

Question by question, read against the document rather than inferred:

| Question | After this decision |
|---|---|
| Q-A1 · is 13 the wrong number | **moot as asked.** The constant stops meaning "may consent unaided" and starts meaning "is an adult". If it is a number at all it is 18, and it is not a consent threshold |
| Q-A2 · are these the right bands | **moot.** No band routes anywhere any more; §1 above is the only question left about the set |
| Q-A3 · what consent must collect and retain | **dead.** The largest single deletion. No consent flow, no evidence columns, ever |
| Q-A4 · is a self-declared date adequate assurance | **transformed and still live.** It stops being *"is this adequate to support a parent's consent"* and becomes *"is this an adequate basis for excluding minors"* — a different question with a different answer |
| Q-A5 · does a platform age signal change Q-A4 | **more relevant, not less.** A parent-set range from Play or Apple is a better exclusion signal than a typed date, and exclusion is now the whole job |
| Q-A6 · do we owe a copy of the data | **live, unchanged in substance.** Its third sub-question — *to whom, when the account holder is a child* — falls away |
| Q-A7 · are 400 and 30 days defensible, and where written | **live.** Same figures, same placement question, now about an adult's data |
| Q-A8 · who else holds the data | **live and entirely unchanged.** Sub-question 3, which asked whether it differs for a child, falls away |
| Q-A9 · does leaving the app need a parental gate | **probably moot, and not on our say-so.** Google Play's Families programme is a store policy rather than a statute, and whether appealing to children puts an app in it regardless of how it is declared was already an open question in §5 line 10 |
| Q-A10 · who writes the notice and terms | **live.** Sub-question 2 — is a child-facing version required — falls away |
| Q-A11 · does local-only processing carry obligations anyway | **survives exactly as far as minors may still play.** Under Reading A they can, offline, and the question is untouched. Under Reading B nobody under 18 plays at all and it goes with them. **Its fate is downstream of §3's open question, not of this one** |

So: **not closed, narrowed to roughly Q-A4 (restated), Q-A5, Q-A6, Q-A7, Q-A8 and Q-A10, plus
Q-A11 conditionally.** That is a consult about an adult product that holds an email address, a
session IP it does not control, and a play history — worth having, and a fraction of the brief that
exists.

**I do not close Gate A on this document's authority, and nobody should read it as closed.** The
brief in `docs/gates/` is written for a child-directed app, cites law it marks as unverified, and
its whole purpose is to leave the building and reach a lawyer. **It must not be sent in its current
form**, because it would ask counsel to answer eleven questions about an audience the product no
longer has. Rewriting it is a separate change; the five-line header added by this one says only
that, and touches none of the questions.

### 3 · ADR 0002 is not superseded, and the reason is worth stating

ADR 0002 decided that Neon Auth holds accounts and nothing syncs until one exists, on a finding
that has not moved: *"There is no configuration of Neon Auth in which a child playing offline has no
row."* Every element of that argument survives — the missing anonymous plugin, the unconfigurable
IP tracking, the 1.4.18 version inside GHSA-qq9h-g4jm-xgf3's range. What changes is only who is
protected by the structure: it kept sessions away from under-13s who were being routed, and now
keeps them away from every minor who is being refused. A decision whose argument is unchanged and
whose scope widens is not superseded. **The GHSA invariant is untouched**: magic-link and email-OTP
stay off while the managed version is below 1.6.22, and this decision has no bearing on it.

### 4 · The dependency rule loses its stated justification — decide it, do not let it lapse

**This is the most consequential downstream effect of the decision and it is deliberately the last
thing in this section, so it is the thing left in the reader's hand.**

`CLAUDE.md`'s opening justifies the rule this way:

> a **mixed audience is governed by its youngest member**, so every protection an under-13 needs is
> unconditional: no third-party SDK that collects data, no ads, no external analytics.

`craftsmanship.md`'s **DEP-1** does the same, in its own words: *"NEVER add a dependency that sends
data off the device […] The audience includes children under 13."*

**That premise is gone.** The rule is not — nothing about this decision makes an analytics SDK
appear — but its *stated reason* no longer holds, and a rule whose reason has died is a rule that
gets argued away by the first person who notices. It must be re-grounded or dropped **deliberately**.

The one piece of good news is architectural rather than rhetorical: **the four gates need no
change.** `app/test/architecture/dependency_allowlist_test.dart` and the three TypeScript
`dependency-allowlist` tests compare manifests and lock files against named lists. None of them
cites the audience; there is nothing in a gate to rewrite. **What has to change is prose, and prose
is exactly what nobody notices going stale.**

Four grounds the rule could stand on instead, none of which is child-derived. They are put here as
candidates, not as a recommendation:

1. **Supply-chain surface.** Four third-party runtime dependencies in `packages/server`, one in
   `packages/contract`, five in `app/` with a 28-package transitive closure, and zero in
   `packages/core`. This rule is why those numbers are what they are rather than an order of
   magnitude larger, and a small audited closure is a security posture on its own terms — it does
   not need a child in it to be worth having.
2. **The recurring-audit argument, which this repository already made in ADR 0003.** *"Every one of
   those fourteen is a package somebody has to audit for phoning home, unconditionally, on every
   version bump, for the life of the product."* 0003 attributed that obligation to the audience
   clause. **The arithmetic survives the attribution** — fourteen recurring audits is a cost whoever
   is playing — but if the clause goes, 0003's sentence needs a different owner too.
3. **LFPDPPP minimisation, which applies to adults.** §2 above: the obligations did not vanish. Data
   never collected is data never protected, never transferred and never deleted.
4. **Two constraints that were never audience-derived at all.** `packages/core`'s zero-dependency
   floor exists so the rederivation machine has no ambient IO, and `zod`'s exact pin exists because
   the pack determinism gate is byte-for-byte. Neither has anything to do with who plays.

**The question in one line, and it is in §*Open* as well: the rule stays — which of these now
carries it?**

> **Amended 2026-08-29 — answered: candidates 1, 2 and 3, and the rule stays a *category* refusal
> rather than going back to a per-dependency question.** See "Amendment: the answers" §2 at the end
> of this record. Candidate 4 is deliberately not enlisted.

### 5 · What else has to be corrected, and by whom

This change is one ADR file plus **two** pointers — the amendment to `ARCHITECTURE.md` §1, and a
five-line **DO NOT SEND** header on the Gate A brief. Everything below is named so it is not lost.
All of it except the Gate A header is **not** touched here — sibling changes own it:

- **`CLAUDE.md`'s opening three paragraphs**, which are the decision this reverses, including the
  *"governed by its youngest member"* justification and the `players.age_band`-as-routing-decision
  sentence.
- **`craftsmanship.md` DEP-1**, lines 185–198, and the section heading at 183 — *"DEP —
  Dependencies & the audience"* — per §4.
- **`ARCHITECTURE.md` beyond §1** — eight lines across seven passages, numbered as they stand
  *after* this change's pointer: 223, 269 (*"ADR 0002 keeps children off it altogether"*), 282 (*"a child's
  device gets no session at all"*), 294 (*"would route a child out of the protections `age_band`
  exists to select"*), 322, 485–487, and the closing note at 535 that places a children's-data
  consult before F1. Each is prose whose subject changed; **none of them is wrong about what the
  system does**, which is why none is corrected here — a sweep that rewords them all at once is a
  cleaner change than eight edits smuggled into an ADR.
- **`docs/gates/gate-a-childrens-data-consult.md`**, per §2 — a **rewrite**, and the sibling's. What
  this change adds to it is only the DO NOT SEND header; nothing in the eleven questions is edited.
- **`docs/IMPLEMENTATION-PLAN.md`**, which names the bands on ten lines.
- **The tutor-consent screen's copy**, which promises an account that will now never arrive.

**No code, no schema and no contract changed in this change.**

---

## Open

> **Amended 2026-08-29 — two of these four are answered and two are not.** See "Amendment: the
> answers" at the end of this record, which maps the replies onto the questions one by one:
> **1 is answered** (Reading A), **3 is answered** (DEP-1 stays a category refusal), the sequencing
> note below is answered (the CHECK is left as it is), and **2 and 4 remain open**. The list below
> is left verbatim as the record of what was unanswered on the day the decision was taken.

Four questions this decision raises and does not answer. Numbers 1 and 2 gate implementation; 3 is
governance and is the one with the widest blast radius; 4 is a real fork with no default.

1. **Reading A or Reading B** — does adults-only mean *no minor gets an account*, or *no minor
   plays*? A is buildable now and leaves offline play untouched. B needs a gate in front of
   `FirstRunGate` and a screen nobody has designed. §*Decision* 3.
2. **What does an under-18 see?** A refusal is not a deferral, and `TutorConsentScreen`'s copy
   becomes untrue the day this lands. This is a design request before it is an engineering task.
3. **Which ground carries DEP-1 now?** §*Consequences* 4 lists four. The rule is presumed to stay;
   what it stands on has to be written down by a human, in `CLAUDE.md` and in the rulebook, or it
   erodes.
4. **Should a refusal be recorded, and where?** Today it is not — the date is discarded, the band
   travels only at link time, and a refused player writes nothing anywhere. Recording it means
   storing a declaration about a minor that is not stored today. Not recording it means the age gate
   leaves no evidence it was ever asked. Both are defensible and neither is free.

And one that is not a question but a sequencing note: **`age_band` — leave the CHECK or narrow it**
(§*Consequences* 1). The measurement recommends leaving it; the choice is the human's, and it can be
made after 1 and 2 rather than before.

---

## Evidence

Every command below was run on 2026-08-29 against `main` at `645e7e9`, macOS arm64. Output is
quoted, not paraphrased.

### 1. The six sites where the band set is stated

```console
$ grep -rIl -e under_13 -e 13_17 -e under13 -e thirteenToSeventeen app packages contract | wc -l
      24

$ grep -rIl -e under_13 -e 13_17 -e under13 -e thirteenToSeventeen app packages contract \
    | grep -vE '(^|/)test/' | sort
app/lib/api/me.dart
app/lib/features/account/policy/session.dart
app/lib/features/auth/policy/age_gate.dart
contract/openapi.json
packages/contract/src/openapi/api-schemas.ts
packages/server/migrations/0001_initial.sql
packages/server/schema.sql
packages/server/src/link.ts
```

Eight outside tests, sixteen inside. Two of the eight are generated artifacts
(`contract/openapi.json`, `packages/server/schema.sql`) and one is a frozen migration.

```console
$ sed -n '57,61p' packages/server/migrations/0001_initial.sql
CREATE TABLE players (
  id          uuid        PRIMARY KEY,
  age_band    text        NOT NULL
                          CONSTRAINT players_age_band_known
                          CHECK (age_band IN ('under_13', '13_17', 'adult')),

$ grep -n 'AGE_BANDS' packages/contract/src/openapi/api-schemas.ts
152:const AGE_BANDS = ["under_13", "13_17", "adult"] as const;
170:  ageBand: z.enum(AGE_BANDS),
175:  ageBand: z.enum(AGE_BANDS),

$ grep -n 'BANDS' packages/server/src/link.ts
23:const BANDS: readonly string[] = ["under_13", "13_17", "adult"];
```

`link.ts` states the set a second time as a local literal rather than importing the contract's —
noted as a cost site, not fixed here.

### 2. `ageBand` is in a request body as well as a response

```console
$ python3 -c "import json; d=json.load(open('contract/openapi.json')); \
    [print(n, '->', json.dumps(s['properties']['ageBand'])) \
     for n,s in d['components']['schemas'].items() if 'ageBand' in s.get('properties',{})]"
Me -> {"enum": ["under_13", "13_17", "adult"], "type": "string"}
PlayerLink -> {"enum": ["under_13", "13_17", "adult"], "type": "string"}

$ grep -n 'PlayerLink' contract/openapi.json | tail -1
1064:                "$ref": "#/components/schemas/PlayerLink"
```

`PlayerLink` is the `POST /players/link` request body, which is why narrowing the enum is expected
to read as breaking rather than as an addition.

### 3. One writer, one call site, no UPDATE

```console
$ grep -rn 'INSERT INTO players' packages/server/src/
packages/server/src/adapters/player-repository.ts:84:    `INSERT INTO players (id, age_band, auth_user_id)

$ grep -rn 'insertPlayer(' packages/server/src/ | grep -v 'export async function'
packages/server/src/adapters/http-server.ts:361:              await insertPlayer(client, {

$ grep -rn 'UPDATE players' packages/server/src/ packages/server/migrations/
                                   # no output, exit 1
```

`http-server.ts:361` is inside the `POST /players/link` handler, on the `case "create"` arm.

### 4. The gate is mounted in exactly one place

```console
$ grep -rn 'AuthFlow(' app/lib | grep -v 'auth/ui/auth_flow.dart'
app/lib/features/profile/ui/profile_route.dart:452:        child: AuthFlow(

$ grep -n 'AgeGateRoute' app/lib/features/auth/policy/age_gate.dart
8:enum AgeGateRoute { createAccount, tutorConsent }
32:  static AgeGateRoute next(AgeBand band) => switch (band) {
33:    AgeBand.under13 => AgeGateRoute.tutorConsent,
34:    AgeBand.thirteenToSeventeen => AgeGateRoute.createAccount,
35:    AgeBand.adult => AgeGateRoute.createAccount,
```

`13_17 → createAccount` is the line that makes this a live behavioural change and not only copy.

### 5. The two labels, read from the workflow

```console
$ grep -n "packages/server/migrations/\*\*" -A1 .github/workflows/ci.yml
178:            'packages/server/migrations/**' \
179-            'packages/server/schema.sql' || true)"

$ sed -n '516,521p' .github/workflows/ci.yml
          if oasdiff breaking /tmp/openapi.base.json contract/openapi.json --fail-on ERR; then
            exit 0
          fi
          case ",$LABELS," in
            *,allow-breaking-contract,*)
```

`git diff --name-only` lists added files, so a new `0009_*.sql` trips `protected-paths` the same as
an edit would.

### 6. The four allowlist gates cite no audience

```console
$ grep -rn -i 'child\|audience\|youngest' \
    app/test/architecture/dependency_allowlist_test.dart \
    packages/server/test/dependency-allowlist.test.ts \
    packages/contract/test/dependency-allowlist.test.ts \
    packages/core/test/dependency-allowlist.test.ts
packages/contract/test/dependency-allowlist.test.ts:20: * dependency of this manifest and not that
   dependency's own children. Both
app/test/architecture/dependency_allowlist_test.dart:43:  // so a child's device can tell right
   from wrong offline without carrying the

$ grep -n 'audience' .claude/conventions/craftsmanship.md
165:  one audience further out, and it is the more serious half — a false comment misleads the next
183:## DEP — Dependencies & the audience
186:  crash reporting, remote config, remote fonts, any SDK that "phones home". The audience includes
```

All four gates were searched. The `contract` hit is the word "children" meaning *transitive
dependencies* and is not about people; the `app` hit is one comment line explaining why `crypto` is
in. **Neither is a predicate** — no gate reads the audience, so no gate has to change. The rule's
stated justification lives in prose: `craftsmanship.md:183` (the section heading itself) and `:186`,
plus `CLAUDE.md`'s opening. All three are sibling-owned.

### 7. What was *not* verified, and it matters

- **The live database was not queried.** The row facts used above — one `players` row carrying
  `adult`, two accounts, seven sessions — are **inherited from Gate A §7, dated 2026-08-26**, not
  re-read today. `TEST_DATABASE_URL` is deliberately unset here and the production strings are not
  this change's to use. Marked the way Gate A §5 marks its own assumptions.
- **The oasdiff classification is an expectation.** `oasdiff breaking --fail-on ERR` is verified to
  run and the `allow-breaking-contract` escape is verified to exist; whether removing a request
  property's enum value lands at ERR specifically was **not** run, because doing so would mean
  making the contract change this ADR recommends against.
- **No legal conclusion is drawn anywhere in this document.** §*Decision* 2 states which
  obligations continue to exist as a matter of engineering fact — what data the system holds — and
  not what the law requires of them. Gate A's disclaimer applies here word for word.

### 8. The committed suite

No code under test was changed by this ADR, so **Tier 1 is unchanged rather than passed**, and this
change reaches **no evidence tier** — Tier 1b has no logic to falsify and Tier 2 has nothing to
exercise. That is the honest outcome, not a skipped step, and it is the same one ADR 0001's
*Evidence* §2 and ADR 0003's *Evidence* §6 record for their own documentation-only changes.

---

## Amendment: the answers — 2026-08-29

**Answered the same day this record was accepted.** That is not a formality worth hiding: the
questions in §*Open* were put to Ervin as soon as the decision was written down, and four answers
came back within the day. They are recorded here rather than folded into the sections above,
because a record that reads as though it never had open questions teaches nobody how the decision
was actually taken.

**Four answers came back, and §*Open* asks four questions, and they are not the same four.** The
count is the trap. Read the mapping before reading the answers:

| Asked here | Status now |
|---|---|
| **Open 1** · Reading A or Reading B | **Answered — Reading A**, §1 below |
| **Open 2** · What does an under-18 see? | **Still open.** Reading A is what makes it urgent, not what settles it |
| **Open 3** · Which ground carries DEP-1 now? | **Answered — the rule stays as a category refusal**, §2 below |
| **Open 4** · Should a refusal be recorded, and where? | **Still open** — and §3 below is what keeps it answerable |
| the sequencing note · leave the `age_band` CHECK or narrow it | **Answered — leave it**, §3 below |
| *(asked nowhere in this record)* · the app-store age rating | **Open**, and being researched separately, §4 below |

So: **two of this record's four questions are answered, the sequencing note is settled, and a
question this record never asked is now on the books.** Open 2 and Open 4 are untouched and stay
untouched — nothing below closes them, and a later reader counting to four should count these
rows instead.

### 1 · Reading A — the refusal happens at link time

**Nobody under 18 gets an account. A minor can install the app and play offline for ever.**
"Adults only" means accounts only.

The reasoning as accepted: **the legal weight comes from holding data, and offline holds nothing on
our side.** Reading A removes the exposure the decision was taken to remove, and it does so without
a screen nobody has designed — §*Decision* 3 measured Reading B's cost as a gate in front of
`FirstRunGate` and a first impression that is a refusal, and Reading A's as one `switch` arm, one
constant and one screen's copy.

**The honest objection from §*Decision* 3 survives being chosen over and is not softened here**:
this makes *accounts* adults-only rather than the *game*. A fourteen-year-old installs it and plays
every day, on-device, and the store listing still reaches them. What Reading A buys is that we hold
nothing of theirs; what it does not buy is that they are not playing.

**This sharpens Open 2 rather than closing it.** Reading A is precisely the branch that needs a
refusal at the gate, so `TutorConsentScreen`'s promise of a later account — *"Mientras tanto tus
retos se guardan en este teléfono"* — becomes untrue the day the switch arm moves. Under Reading B
that screen would have been bypassed entirely. The design request is now on the critical path.

### 2 · DEP-1 stays, as a category refusal, on three grounds that were never child-derived

**Analytics, ads, attribution and crash reporting stay refused *as a category*, not case by case.**
The rule does not change. **Its stated reason does, and that is the whole of this answer** —
§*Consequences* 4's warning was that a rule whose reason has died gets argued away by the first
person who notices, and the answer is to re-ground it rather than to let the category quietly go
back to being per-dependency.

Three of the four candidates in §*Consequences* 4 are adopted, and each stands without an audience
clause:

1. **Supply-chain surface.** Four third-party runtime dependencies in `packages/server`, one in
   `packages/contract`, five in `app/` with a 28-package transitive closure, zero in
   `packages/core`. A small audited closure is a security posture on its own terms.
2. **The recurring-per-version audit, which is ADR 0003's own argument.** *"Every one of those
   fourteen is a package somebody has to audit for phoning home, unconditionally, on every version
   bump, for the life of the product."* 0003 attributed that obligation to the audience clause;
   the arithmetic never needed it, and it now stands on its own. **0003's sentence has a new owner
   and its conclusion is unchanged.**
3. **Data minimisation under the LFPDPPP, which applies to adults.** §*Decision* 2: the obligations
   did not vanish with the children's-data regime. Data never collected is data never protected,
   never transferred and never deleted.

The fourth candidate is **not** adopted as a ground, and that is deliberate rather than an
oversight: `packages/core`'s zero-dependency floor and `zod`'s exact pin are constraints of their
own, held by the rederivation machine's no-ambient-IO rule and by the byte-for-byte pack
determinism gate. They were never audience-derived, so they were never at risk, and enlisting them
as supports for DEP-1 would make one rule look like it was carrying two others.

**Nothing in a gate changes**, as §*Consequences* 4 already established by measurement: the four
`dependency-allowlist` tests cite no audience and read no predicate about who plays.

### 3 · The `age_band` CHECK is left exactly as it is

**No migration 0009. No contract change. No `allow-protected-edit`, no `allow-breaking-contract`,
no re-emitted `openapi.json`.** §*Consequences* 1 measured both options and the cheap one is taken.

The reason is the measurement, restated as the decision: **`age_band` is written by exactly one
`INSERT`, nothing anywhere `UPDATE`s it, and under Reading A a refused minor never links.** So
`under_13` and `13_17` **go dead by construction** — no row can ever again carry either, whether or
not anybody deletes the values. Narrowing the CHECK would buy the same guarantee at the price of a
forward-only migration, a regenerated snapshot, two protected-path labels, four hand-written edits,
sixteen test files and a re-emitted contract.

**The schema keeps a vocabulary it no longer issues, and that is the point rather than a leftover.**
§*Consequences* 1 already stated what narrowing would destroy: *"Narrowing the CHECK removes the
only vocabulary in which a declared band could ever be recorded — which is precisely §3's open
question about recording a refusal. Deleting the values forecloses it."* **Leaving the CHECK is
therefore what keeps Open 4 answerable at all.** Whoever answers it inherits a column that can
still hold the answer.

One consequence for the sibling plan, stated because that plan says the opposite: its *What
changes* section has `AGE_BANDS` collapsing to `["adult"]` and the pull request carrying
`allow-breaking-contract`. That half is overruled. The de-duplication it also proposes —
`link.ts`:23 stops retyping the band set and derives it from `@akimath/contract` — is **not**
overruled and never depended on the narrowing; it is worth doing on its own, and §*Consequences* 1
already noted `link.ts` as a cost site tied to no gate.

### 4 · The app-store age rating is open, and somebody owns it

**Ervin is researching it separately, and nothing here invents one.** An adults-only product has a
rating to declare and this repository contains no passage that declares one — a gap the sibling
plan found and could not fill, and which this record never asked about, so it enters the books here
for the first time.

It is recorded as an open decision in `docs/decisions/OPEN.md` rather than as an answer, because
that file is for exactly this and it survives the archiving of any plan. Two things it is not: it
is **not** a reason to reach for §*Decision* 3's Reading-B-adjacent "the store declares it and the
app does not ask" — the sibling plan's D3 already showed that option is unavailable until a rating
exists, and Reading A is now chosen regardless — and it is **not** blocking anything, because
Reading A asks in the app whatever the store says.

### What these answers do not touch

- **ADR 0002 is still not superseded**, for the reason §*Consequences* 3 gives. Reading A widens
  the same structural protection rather than replacing it: a minor still never obtains a session,
  now because the gate refuses rather than because it routed. The GHSA invariant is unchanged.
- **Gate A is still narrowed rather than closed**, per §*Consequences* 2, and the brief still
  carries its **DO NOT SEND** header. Nothing above answers any of Q-A4 through Q-A10.
- **No threshold moves because its stated reason did.** The 48 px touch floor and the `textScaler`
  1.3 viewport were justified in prose by a child's aim and a child's device. Both stand on
  platform floors and on adults being the population that most raises system text size; the
  sentences beside them are corrected in the same change as this amendment, and the correction
  makes relaxing them harder rather than easier.
