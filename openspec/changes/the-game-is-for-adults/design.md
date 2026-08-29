# Design

Written for the recommended answers. Where a section says a human decides, the recommendation is
reasoning and not a decision, and D3 in particular is written knowing that one of its three options
would make half of this plan wrong on purpose.

## D1 — The column survives, collapsed to one value

Two coherent answers, and the weaker one is more tempting than it looks.

**Drop it.** A column with one legal value carries no information. Every row says `adult`, no
handler branches on it (verified across `packages/server/src/`), and a field that cannot vary is a
field that cannot be read for anything. By that argument the honest schema after this decision has
`id`, `created_at` and `auth_user_id`, and nothing about who a player is.

**Collapse it.** `players.age_band` is the only thing the schema records about a player at all —
`players.test.ts`:112–140 sweeps `information_schema.columns` for a name or a date of birth and
finds none, deliberately. Drop the band and the schema records *nothing*, which is not the same
statement as "we ask nothing": **"we asked and they said adult" is a different fact from "we never
asked."** The first is a position a store review or a data authority can be shown. The second is
indistinguishable from never having had a policy.

**The second wins, on four grounds, in ascending order of how hard they are to argue with.**

1. **A single-valued column still costs nothing.** One `text` per row, no branch anywhere, no
   index. The information-theoretic objection is true and priced at zero.
2. **The reversal is asymmetric.** Widening a CHECK back to three values is one forward-only
   statement — `0001_initial.sql`:53–54 chose a CHECK over an enum *for exactly this reason* and
   says so. Re-adding a dropped `NOT NULL` column to a populated table needs a value to invent for
   rows that predate the concept, which is the wall `f3-players-belong-to-an-account` D3 hit and
   solved only because the table was empty. It will not be empty next time.
3. **Dropping it is more breaking, not less.** See D4. Narrowing an enum breaks the request half;
   removing a required property from `Me` breaks the **response** half as well, and forces the Dart
   client to change in the same beat.
4. **The record is the point, and it has a load-bearing condition.** The column is only evidence
   that a question was asked if the value *came from the device's answer*. That is what D2 is about,
   and it is why these two questions cannot be settled separately.

## D2 — And so does the field on the wire — which is the half that makes D1 true

`ageBand` is a **required** property of `PlayerLink` with `additionalProperties: false`. Once the
enum has one member, the obvious tidy-up is to stop sending a field a client cannot get wrong.

**Two coherent answers again, and this time the cheap one destroys the expensive one's argument.**

**(a) Keep it required, over one value.** The device still declares. `req-the-link-request-can-create-the-row`
stays green with no exclusion, and the row keeps recording *what the player answered*.

**(b) Drop it from the body; the server writes the constant.** Cheaper on the wire. But
`req-the-link-request-can-create-the-row` demands that every `NOT NULL`-no-default column of
`players` be a required property of the link body, so `age_band` would have to join the named
exclusion map beside `auth_user_id` with *where the value comes from instead* — the shape
`f3-players-belong-to-an-account` D4 built. That is mechanically fine. What is not fine is what it
does to D1: **if the server writes `adult` unconditionally, the column records the server's policy
rather than the player's answer**, and the whole "we asked and they said adult" argument evaporates.
The row would be evidence that an `INSERT` ran.

**(a) is the recommendation**, and the honest cost is stated rather than hidden: a required enum
with one member is a field no caller can get wrong, and somebody will call it dead weight. It is
dead weight that keeps the seam open. The day the record has to be strengthened — a timestamp on the
declaration, an attestation, whatever a consult asks for — (a) has a field to strengthen and (b) has
to re-introduce one first, breaking the contract a second time to undo a tidy-up.

Neither answer is available before D3 is settled, because one of D3's options removes the
declaration entirely.

## D3 — Where the refusal happens is a product decision, not a screen decision

**This is question 2, it is a human's, and it is the one that gates everything else.** The framing
*"the gate stops routing and starts refusing"* does not settle it, and the difference is not
cosmetic.

Today the band is resolved by `AgeGate` standing in front of `1.2 Crear cuenta` — that is, **at link
time only**. Unlinked play is entirely offline by ADR 0002 and asks nothing. So "adults only" has at
least three readings.

### Option 1 — refuse at link time

The gate stays exactly where it is and `AgeGateRoute.tutorConsent` becomes a refusal instead of a
consolation. An under-18 keeps playing offline for ever and simply cannot make an account.

- **Smallest change.** One screen — `tutor_consent_screen.dart`, already registered in
  `screen_registry.dart`:341–344 — changes what it says. `AgeGate.next` keeps two arms with
  different names. No new entry point, no new persisted state.
- **The honest objection.** This means *accounts* are adults-only, not the *game*. A fourteen-year-old
  installs it and plays every day. If the decision's purpose is to stop carrying the legal weight of
  a mixed audience, this option does not deliver it — the app is still used by minors, it still
  processes their answers on-device, and the store listing still reaches them.

### Option 2 — refuse at app open

`FirstRunGate` gains the age question before `0.2 Bienvenida`. An under-18 reaches no playable
content at all.

- **This is what the sentence plainly means**, and it is the only option under which the mixed
  audience genuinely ends.
- **Costs, all real.** A screen nobody has designed, reached before anything else in the app. A
  persisted refusal, or it is one relaunch away from being bypassed — and `shared_preferences` is
  wiped by an uninstall, which is documented in `CLAUDE.md`'s simulator recipe, so the refusal is
  trivially bypassable **whatever** is built. Worth saying out loud before anyone treats the gate as
  enforcement: a self-declared date of birth is a statement of policy, not a control.
  Every integration test that reaches the home walks an age question first, and the first-run
  suites move with it.
- It also makes the product's first impression a refusal risk, which is a design question and not
  this plan's to answer.

### Option 3 — the store declares it and the app does not ask

No in-app refusal. The age rating and the listing carry the claim.

- **Zero code**, and honest about what a self-declared birth date achieves.
- **It unpicks the contract half of this plan.** With no in-app declaration, `PlayerLink.ageBand:
  "adult"` is the device asserting something nothing established — worse than today, where the gate
  at least asked. Under Option 3 the coherent shape is D2's answer (b), the server writes the
  constant, and D1's argument for keeping the column goes with it.
- It also has nothing to point at: no age-rating passage exists in any document swept, so "the store
  declares it" is currently a claim about an artifact that does not exist.

**Which means option 3 is not available today, and that is a conclusion the three facts above force
rather than an opinion about it.** Put them together: the app would make no claim, the store carries
no rating because none has been declared, and the wire would still assert `adult` on no basis at
all. That is strictly worse than the status quo on the one axis this decision was made to improve —
today the gate at least asks. Option 3 is therefore a **sequencing question, not a third peer
option**: task 0.5 has to produce an age rating before it can be chosen, and until it does the
human's choice is between 1 and 2.

**Recommendation: none, and that is deliberate.** Options 1 and 2 differ in product ambition, not in
engineering, and **everything in `tasks.md` sections 1 through 4 is identical under both** — which is
what makes the schema and contract work startable the moment the human picks either. **Option 3 is
not neutral**: pick it and D1, D2 and the delta specs in this change are wrong on purpose, in the
same way `decide-the-keypad-offers-what-it-accepts` is written for its Option B and says so.

## D4 — Narrowing is breaking, and the two directions are different questions

The verdict first: **breaking, and the pull request needs `allow-breaking-contract`.**

The discriminating fact is *who holds the value set*, not *that a set got smaller*.

- **Request enums are narrowed against clients that already send the removed values.** A shipped
  device sending `13_17` gets a 400 it never used to get. The producer of the value is the party
  that breaks, and the producer is out there.
- **Response enums are narrowed against clients that already handle the removed values.** A consumer
  written for three receives one of the three. Nothing it can do fails. The break in the response
  direction is *adding* a value, not removing one.

`ageBand` sits in both — `PlayerLink` (request) and `Me` (response) — so the request half decides
it, and the response half is compatible. That asymmetry is what D1 ground 3 rests on: **dropping the
property outright would break the response half too**, because removing a required property from a
response is a break in the direction that narrowing its enum is not. "Drop it" is strictly the more
expensive contract move, which is a cost argument on top of D1's evidence argument.

**This reasoning is not the evidence.** `f3-link-carries-the-band` D3 recorded a rule id and an exit
code against the pinned binary — `new-required-request-property`, exit 1 — and that is the standard
here. Task 1.2 does the same for this change, and it is a task rather than a precondition because
the answer changes nothing about the plan: the label is needed either way, and a *non*-breaking
verdict would only mean the gate is asleep again, which is itself worth knowing. That has happened:
D5 of the same archived change found this gate had never once run.

## D5 — The set gets one home before it gets one value

`api-schemas.ts`:145 says the band set is *"declared once"*. It is declared **four** times by hand —
that comment, `link.ts`:23, `0001_initial.sql`:61, and (derived, but committed and diffed) the two
enums in `contract/openapi.json` and the CHECK in `schema.sql`. Ten sites in all once the retyped
test literals are counted.

Three of the four are tied together already: `link-request.test.ts`:135–152 reads the enum out of
the committed contract and inserts every value into the real table, so `openapi.json` and the CHECK
cannot disagree. **`link.ts`:23 is tied to nothing.** No test references it, and `grep -rn
"AGE_BANDS" packages/server/src` is empty. It can drift silently in either direction: refuse a band
the contract offers, or accept one the CHECK will reject at insert time — a 500 where
`req-refused-before-the-database` promises a 400.

So the de-duplication is **task 2 and it lands before the narrowing**, for two reasons that are
separately sufficient. It turns a four-place edit into a one-place edit, so the narrowing cannot be
done three-quarters of the way. And it is worth doing whether or not this decision is ever carried
out, which means it does not have to wait on D3.

`@akimath/contract` is already a `file:` runtime dependency of `packages/server`, so the import
costs nothing and adds nothing to the allowlist. Deriving the set from `PlayerLinkSchema`'s own
`options` rather than exporting a second constant is one fewer thing to keep in step; either way
the test is what makes it stay derived.

**PURE side.** `link.ts` is pure and stays pure — importing a frozen literal from another package is
not IO. `readLinkRequest` keeps deciding, and the adapter keeps not deciding.

## D6 — DEP-1 keeps its rule and loses its unconditional

`.claude/conventions/craftsmanship.md`:185–199 is one rule, and only its second sentence is
audience-derived: *"The audience includes children under 13 and the compliance posture in
`ARCHITECTURE.md` §11 is minimization by construction."* Everything else — audit before adding,
write the audit beside the allowlist entry in the same change, `shared_preferences` as the worked
example — is audience-independent and enforced by four tests that do not know who plays.

The distinction worth being precise about: **DEP-1 has always been a per-dependency human gate.**
What the mixed audience added was a pre-decided answer for one category, and it is that pre-decision
the premise was holding up. Removing it does not delete the gate; it un-decides one category's
answer.

**Recommendation: keep the rule, restate the reason, and record the change in status.** The rule
survives on three independent supports — `packages/core`'s zero dependencies as an architectural
property, an offline model with nothing to report and no credential to report it with, and four
tests already written and already biting. What it loses is the word *unconditional*, and losing it
honestly is better than keeping it on an argument that is no longer available. Somebody will
eventually notice the premise is gone; better they find the reasoning already updated than find a
rule defended by a deleted sentence.

**It goes to `docs/decisions/OPEN.md` and not into this change's code**, because that file exists
for precisely this — *"things the code is currently doing one way, that nobody has decided should be
done that way"* — and because an entry there survives the archiving of this plan. The costs are in
the proposal's own section, measured against the 28-package closure on disk rather than estimated.

## D7 — A `MODIFIED` requirement is matched on its whole header, and that was measured

Four requirements are modified here and none of them is retitled. That is not a stylistic choice.

`openspec validate --strict` matches a `## MODIFIED Requirements` block against the current spec by
the **entire** `### Requirement:` line, id and title together. Measured on this change before any of
it was written, in three runs:

- Header copied exactly, one scenario omitted → **error**, naming the omitted scenario.
- Header retitled, every scenario present → **valid**.
- Header retitled, one scenario omitted → **valid**.

The second and third are the trap. A retitle does not fail; it silently stops matching, so `archive`
merges a **second** requirement alongside the original instead of replacing it. A `MODIFIED` block
also replaces the whole requirement, so every scenario the current spec has must be reproduced even
when the change does not touch it.

Both titles this decision makes awkward turn out to survive on their own terms, which is lucky
rather than clever. *"A player carries a coarse age band and never a name"* is still exactly true —
the band is coarser than ever. *"A bad band is a 400, never a 500"* is still exactly true, and with
one legal value the rule has *more* to catch, not less. Had either needed renaming, the correct
instrument is `## RENAMED Requirements` or a `REMOVED` plus an `ADDED` under a new id — never an
edited title inside `MODIFIED`.

## D8 — What this change deliberately cannot verify

Three things, named so that nobody mistakes the plan's confidence for evidence.

- **The live database was not queried.** The claim that the one `players` row carries `adult` comes
  from `docs/gates/gate-a-childrens-data-consult.md` §7 and Q-A2, recorded 2026-08-26, plus the
  project owner's own account. `packages/server/.env.local` is gitignored and a production query is
  not a session's to run unattended. Task 1.1 is where a person makes it a fact.
- **`oasdiff` was not run.** D4 argues the verdict; the binary is version-pinned in CI and
  downloading one is a person's call. Task 1.2 records the rule id and the exit code.
- **The refusal screen has no design.** The Claude Design project is read-only from a session
  (`CLAUDE.md`, *Where the design lives*), and no document in it draws an under-18 refusal. This
  plan invents no es-MX copy for it, which is a deliberate hole and not an oversight — the
  repository has already paid twice for treating a digest as a source, and inventing the source
  outright is worse.
