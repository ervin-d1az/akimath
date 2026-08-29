# Gate A — consult brief: adult personal data in an adults-only service

**For:** a lawyer specialised in personal-data protection in Mexico.
**From:** Ervin Diaz, AkiMath.
**Opened:** 2026-08-16, as a children's-data brief. **Rewritten:** 2026-08-29, the day the product
became adults-only.
**Supersedes:** `gate-a-childrens-data-consult.md`, in this same directory. That document is kept as
history and **is not the one to answer.** It is why several values in the running system look the way
they do — the age bands are in a frozen database constraint because of it — so it is worth having
next to you, but where the two disagree this one is later and this one is correct.
**What we need back:** a short written answer per numbered question, cited by number. Not a memo.
**Eleven questions, and they are not the old eleven** — §2 is the full accounting of what died, what
survived and what the decision itself created.

**Nothing in this document is legal advice, and nothing in it should be read as our legal position.**
It is an engineering plan's list of open questions, each stated with the default the running system
currently encodes, so that your answer is a one-line change rather than a redesign.

**Everything asserted here about the running system is marked *Verified* or *Assumed*, and so is
everything asserted about the law.** *Verified* means somebody read it off the code or the database
on the date given. Treat the *Assumed* ones as questions too.

---

## The answer we already believe, put first so you can disagree with it early

> **The adults-only decision makes this consult smaller and more ordinary. It does not close it.**
>
> It retires the two heaviest items — what a parental-consent flow must collect and retain as
> evidence, and the whole Google Play Families surface. Those were the ones with schema consequences
> and a store-review consequence, and they are genuinely gone.
>
> It touches **neither of the two sharpest**. Our erasure path does not delete the identity-provider
> account, so an email address, a password hash and an account name survive a user asking us to
> erase them. And every sign-in records an IP address and a user-agent that we did not ask for,
> cannot switch off, and have set no retention period for. Both were true yesterday and are true
> today; nothing about the audience changed either one.
>
> **An adult's personal data is personal data.** The privacy notice, the deletion path, the export
> right and the retention figures all survive this decision intact. What changed is that they are
> now an ordinary controller's obligations rather than a child-protection problem — lighter, and
> not gone.

---

## 1 · What changed on 2026-08-29, and exactly which door it closes

**The decision, taken by the project owner:** AkiMath is offered to adults only. It is recorded in
its own ADR, a sibling change landing alongside this brief.

**Read the next paragraph before anything else, because the rest of this document turns on it.**

**"Adults only" is a term of service and an account gate. It is not a technical impossibility, and
no version of this app can make it one.**

- *Verified, 2026-08-29, by reading the code.* The age gate
  (`app/lib/features/auth/policy/age_gate.dart`) has exactly two destinations and stands in front of
  exactly **one** door: the form that creates an account. Its only caller is the account screen
  inside the profile tab. **Nothing gates play.** A device that never opens an account never meets
  the gate, never transmits anything, and plays indefinitely against a file bundled inside the app.
- So a person below the age line can still install AkiMath and use it. What they cannot do is create
  an account — and therefore cannot cause a single row to be written on our side, because the
  account is the only thing that reaches the server at all.
- *Assumed — the product intent, not yet the code.* The eligibility line moves from **13** to **18**,
  and the middle band (13–17) joins the refused side. **The code today still says 13**
  (`AgeGate.consentAge = 13`, *verified 2026-08-29*), and a 13–17 device is still routed to the
  account form. Making that true is the implementation change this brief accompanies. It has not
  happened yet, and until it does the system in front of you is still the one described below.

**So the question we are putting to you is: what does an adults-only service holding a small amount
of adult personal data have to do in Mexico — and what, if anything, does it still owe a minor who
installs it and plays it offline against our own terms?**

The second half of that sentence is not rhetorical. It is Q-A11, and it is the one place where the
old brief's subject matter survives essentially untouched.

---

## 2 · The accounting: what died, what survived, what the decision created

The old brief asked eleven questions. **Two are dead. Nine survive, all of them in a changed form.
None survives unchanged. Two are new, created by the decision itself.** Eleven again, and a
different eleven.

| Old question | Fate | Why |
|---|---|---|
| Q-A1 · is 13 the wrong number | **Changed shape** | The constant survives with a new value and a different job: not "may consent for themselves" but "may use the service at all" |
| Q-A2 · are these the right bands | **Changed shape** | The band *set* collapses toward eligible / not eligible, and it acquires the question the old brief never had to ask: may we record a date of birth at all |
| Q-A3 · what must a parental consent collect and retain | **Dead** | No minor may hold an account, so there is no consent to obtain and no evidence to retain. **This is the largest single thing the decision buys** — it was the question with the biggest engineering consequence, and the columns it would have created stay permanently unbuilt |
| Q-A4 · is a self-declared date adequate assurance | **Changed shape** | The duty it asked about — reasonable efforts to verify a parent — is gone. The question becomes what standard of assurance an *eligibility* gate owes, which is not obviously the same standard, and may be higher |
| Q-A5 · does a platform age signal help | **Changed shape, and more relevant** | The parental-approval branches stop mattering; the *verified adult* status becomes precisely what an eligibility gate wants |
| Q-A6 · do we owe a copy of the data | **Changed shape** | *Acceso* belongs to any data subject, so the question survives whole; only "to whom, when the holder is a child" dies. It absorbs the erasure-completeness question, which is the sharpest thing in this brief |
| Q-A7 · are 400 and 30 days defensible | **Changed shape** | The figures are unchanged and still open; the justification for them changes from a child's data to an adult's, and the COPPA comparator that anchored half the question no longer applies to us at all |
| Q-A8 · who else holds this data | **Changed shape** | Only sub-question 3 — "does it change when the address belongs to a child" — dies. Cross-border transfer survives and becomes more central, not less |
| Q-A9 · does leaving the app for a legal document need a parental gate | **Dead** | Its whole premise was Google Play's Families programme, which an adults-only app is not in. What replaces it is a store-declaration question for `f3-store-artifacts`, not a question for counsel |
| Q-A10 · do you write the notice and terms, or review ours | **Changed shape** | The child-facing version dies. The authoring question survives, and the notice gains new content: the eligibility statement, and what we do if we learn a holder is not eligible |
| Q-A11 · we process a child's data on their own device — does that carry obligations | **Changed shape, and it is the survivor that surprised us** | ADR 0002 answered the *design* question. It never answered the *legal* one, and the decision does not answer it either: a minor can still install the app and play offline. Only its sub-question 2 dies |

**New, because the decision created them:**

| New question | Why it did not exist before |
|---|---|
| Q-A12 · what may we keep about somebody we refused | There was nobody to refuse. Under the old design an under-13 was routed onward to a consent flow; under this one a person is turned away, and turning somebody away is itself a thing you may or may not be allowed to remember |
| Q-A13 · an account holder turns out to be under 18 — then what | Under the old design that person was entitled to be there with a parent's consent. Now they are not, and terms that say 18+ with no enforcement behind them may be worth less than terms that say nothing |

**Two things this table deliberately does not do.** It does not keep a question alive because it
mentions a child — Q-A6 and Q-A8 were only ever about *personal data* and used a child as the
example. And it does not keep a question alive out of caution: Q-A3 and Q-A9 are gone, and nothing
below asks about parental consent or the Families programme.

---

## 3 · The product, in the detail that matters here

**AkiMath** is a mobile app (iOS and Android) that gives adaptive arithmetic challenges in Mexican
Spanish, with a dog called Aki as the mascot. Markets for the first version: **Mexico and
Spanish-speaking Latin America. No United States launch.**

What the app is *not*, because each absence removes a category of obligation and you should not have
to ask. *Verified 2026-08-27 against each package's manifest and lock file, and enforced by a test
in each of the four:*

- **No advertising, of any kind.** No ad SDK, no ad network, no sponsored content.
- **No third-party analytics, no crash reporting, no attribution SDK, no A/B testing service.**
  Besides Flutter itself the app ships four runtime packages — `cupertino_icons`, `meta`,
  `shared_preferences` and `crypto` — none of which makes a network call, and a test refuses a
  fifth. The only code that opens a socket is our own.
- **No social features.** No chat, no friends, no sharing, no user-generated content, no leaderboard.
- **No display name shown to anyone, and no username** — but **the identity provider's account does
  carry a name field and it is populated.** It is never displayed, never sent to another player, and
  our own `players` table has no column for it. See §3.1.
- **No photos, no camera, no microphone, no location, no contacts, no device advertising identifier.**
- **No push-notification service.** There is no push token and no messaging provider.
- **No payments in the first version.**
- **Offline first.** A device with no account plays entirely against a file bundled in the app and
  nothing leaves the phone. Once an account exists the device fetches a pack from our server and
  later sends back what was answered; those answers are graded against a digest, so the server can
  confirm or deny a guess without ever being told the authored answer.

The app is therefore intentionally close to collecting nothing. The questions below are almost all
about the small amount it does collect now that accounts exist, and about the paperwork that
accompanies it.

### 3.1 What is collected, in full

This is the complete inventory. Nothing else is collected and nothing else is planned.

Everything below sits in one hosted Postgres database run by a third-party database provider. Two
schemas in it: our own tables, and the identity provider's, which is managed Better Auth running
inside that same database. That provider is not a separate company holding a copy; it is a managed
service over the same store. **No transactional email provider has been chosen** — Q-A8 is still
open, and until it is answered nothing has been shared with one.

**On the last column.** *These counts were read off the live database on 2026-08-26 and have
deliberately not been re-read for this rewrite.* They are carried forward with their original date,
because a re-stamped date on a reading nobody took again is worse than a stale one. Nothing has been
distributed since, so they are unlikely to have moved; "unlikely" is the correct strength.

| Datum | Where it comes from | Why | Retained | Counted 2026-08-26 |
|---|---|---|---|---|
| `player_id` — a random UUID | Generated on the device at first launch | The only identifier for a player's progress; it is not derived from the device or the person | Until deletion | **1 row** |
| `age_band` — one of a small set of ranges | Derived on the device from a date the user enters; **the date itself is discarded and never transmitted** (*verified 2026-08-29*) | Was: to route into child protections. **Now: the record that we checked eligibility** — a different job for the same column, and Q-A2 asks whether it is still the right one | Until deletion | **1 row**, `adult` |
| Email address | Typed by the user when creating an account | Sign-in, and the deletion-confirmation link | **Survives our erasure path** — see below | **2 accounts**, both verified |
| Password hash | Derived from a password the user chooses | Sign-in | Same as the email — held by the identity provider | **2 accounts** |
| Account display name | Typed at sign-up because the identity provider requires a value | Nothing. We never display it, never send it to another player, and our own `players` table has no column for it | Same as the email | **2 accounts** |
| Session IP address and user-agent | Recorded automatically by the identity provider for every session | Nothing we asked for — see the note below | **No period we set.** Our retention job does not touch these rows. The session itself expires 7 days after sign-in; whether the row is then deleted or merely invalidated is the provider's behaviour and **we have not verified which** | **7 sessions**, none yet expired |
| `attempts` — one row per exercise answered: which item, what was typed, whether it was right, when | The player's own play | Adaptive difficulty and the player's own progress view | **400 days** — see Q-A7 | **0 rows** |
| `user_skills` — a numeric skill rating per topic | Computed from attempts | Choosing the next exercise's difficulty | Until deletion | **0 rows** |
| `diag_events` — a row noting which misconception an error matched | Computed from attempts | To improve the explanations the app gives | **30 days** — see Q-A7 | **0 rows** |
| `offline_packs` — which exercises were downloaded for offline play | The server | To re-verify offline answers when the device reconnects | Until expiry or deletion | **3 rows** |

**No date of birth appears anywhere in this table, or anywhere in the schema.** *Verified
2026-08-29:* the initial migration says so in a comment and the schema bears it out — the date is
reduced to a band on the phone and discarded there. Whether an adults-only service is *allowed* to
keep working that way, or whether an eligibility record needs to be more than a band, is Q-A2.

Four things worth naming, because they narrow the questions:

- **A player's own answers are never sent to other players and never leave our own database.** There
  is no path by which one player's data reaches another.
- **IP address and user-agent are recorded and cannot be switched off.** The setting is not
  configurable in the managed service, and every session row carries both; all seven sessions in the
  database on 2026-08-26 had both populated. This is written up in `docs/adr/0002`. The old brief
  could point to a structural mitigation — a device below the threshold never obtained a session, so
  no minor's IP was ever recorded — and **that mitigation survives the decision and gets stronger**,
  because the threshold rises. What it never covered is the adult, and the adult is now every user
  we have. **This is the one datum here with no retention period of ours**: Q-A7's two figures cover
  attempts and diagnosis events, and the retention job sweeps only our own tables. Whether these
  rows need a period, and whose job it is to set one, is Q-A7's third sub-question and it is
  entirely untouched by the adults-only decision.
- **Our erasure path does not erase everything above.** `DELETE /me` removes the `players` row and
  everything that references it — attempts, issued items, offline packs, skill ratings and diagnosis
  events — and this is verified by a test that counts the rows in each table rather than trusting
  the schema to still say so. **It does not delete the identity-provider account**: the email
  address, the password hash and the display name survive it, and removing those is a separate act
  at the provider. That scope is written into the frozen API contract itself (*verified 2026-08-29*
  — the operation's own description says so) rather than left to be inferred from a `204`. Whether
  that is an acceptable answer to an *acceso* or *cancelación* request is squarely a question for
  you, it is the sharpest edge in this document, and **the adults-only decision does not touch it.**
- **The public deletion page does not exist yet.** Erasure is available inside the app. The page that
  works without installing the app is designed and unbuilt (`f3-deletion-web`), which also means the
  retention figures in Q-A7 are published nowhere user-facing today.

---

## 4 · The questions

Each question states **the default the running system currently encodes**. In several cases
confirming the default is the whole answer. The surviving numbers are unchanged from the superseded
brief on purpose — the code comments and the implementation plan cite them by number.

---

### Q-A1 · Is 18 the right line, and is it the line Mexican data-protection law actually draws?

The system uses a **single named constant** for the age at which a person may open an account.
*Verified 2026-08-29:* its value is still **13**, chosen as the floor the United States' COPPA sets.
The adults-only decision replaces that with **18**, and it also replaces the constant's *job*: it no
longer means "may consent for themselves", it means "may use the service at all".

Two things we want confirmed, and they are not the same thing:

1. **Is 18 the correct line for eligibility** under Mexican law, or is the age at which a person may
   validly consent to the processing of their own personal data a different number from civil-law
   majority? We have assumed they coincide and we have not verified that they do (§6, row 5).
2. If they do not coincide, **which one governs an eligibility term** — is refusing service to a
   17-year-old who could lawfully consent for themselves a data-protection question at all, or is it
   purely a contract question?

> **Default encoded:** 13 in the code today; 18 as decided and not yet built.
> **What changes if you say otherwise:** one named constant, and the shape of Q-A2's band set.
> Nothing else.
> **What we need:** the number, and whether it is the same number for both jobs.

---

### Q-A2 · What may we record about a person's age — and may we record a date of birth at all?

*Verified 2026-08-29.* The app stores a band and never a date. These are the three values, quoted
from the database constraint that exists — `players.age_band`, frozen 2026-08-17:

```
under_13 · 13_17 · adult
```

Under adults-only, two of those three can never be written again by a device that respects the gate,
and the set collapses toward a single meaningful distinction: eligible, or refused.

**Three sub-questions, and the second is the one the old brief never had to ask:**

1. **Is a band still the right thing to store?** An eligibility check that leaves behind only
   `adult` records that we checked, and nothing about what we checked.
2. **May we record a date of birth at all — and if we may, for how long, and would we then have to?**
   Our instinct is that a date is more data than we need and that we should keep discarding it. But
   an eligibility gate that keeps no evidence of the declaration is also a gate that cannot show it
   ran. We would rather be told which of those two considerations wins than pick.
3. **Must the refused-side value exist in the record at all?** See Q-A12 — that is the same question
   from the other end.

> **Default encoded:** three bands, boundaries at 13 and 18, date discarded on the device.
> **What changes:** a `CHECK` constraint in the database and one screen's options. It is deliberately
> a `CHECK` rather than an enumerated type: replacing a `CHECK` is one forward-only statement, while
> an enumerated value can never be removed once it exists. One live row uses `adult`
> (*counted 2026-08-26*), so a change to the set also means moving that row — a cost, but a small and
> knowable one.

---

### Q-A4 · What standard of age assurance does an *eligibility* gate owe?

*Verified 2026-08-29.* The app asks for a date of birth in a neutral field — not a leading
*"¿eres mayor de edad?"*, which invites the answer that unlocks the app. The date is converted to a
band **on the phone** and the date itself is then discarded; only the band is ever transmitted.

The old brief asked whether that satisfied a duty to make *reasonable efforts* to verify a parent's
consent. **That duty is gone with Q-A3.** What replaces it is a question we think may be harder, not
easier:

1. **Does an adults-only service owe any standard of age assurance at all** under Mexican
   data-protection law, or is the age term purely a matter of contract with no data-protection
   dimension?
2. If it owes one, **is that standard higher than the one a consent gate owes?** A consent gate that
   guesses wrong routes a child into a protective flow. An eligibility gate that guesses wrong lets a
   child into a service that has told the world it does not admit them — the failure runs in the
   opposite direction, and we cannot tell whether that makes the bar higher or simply different.
3. Does a self-declared date, reduced to a band and discarded, meet whatever that standard is for a
   service of this size?

> **Default encoded:** neutral date entry, reduced on device, date discarded.
> **What changes:** if a stronger mechanism is required, it is a new screen and possibly a processor.

---

### Q-A5 · Does a platform-supplied age range help more than a self-declared date?

Both app stores now offer to tell the app the user's age *range*, without ever disclosing a birth
date:

- **Google Play Age Signals API** — announced for worldwide rollout by the end of 2026, so it reaches
  Mexico. Age ranges are not shared by default; parents control them from Family Link.
  *(Verified via Google's developer blog, July 2026 — see §6.)*
- **Apple Declared Age Range API** — already live and expanding beyond the United States. Parents set
  a range; it is shared only with permission; no birth date is involved. *(Verified, §6.)*

**This question got more relevant, not less.** The old brief cared about the parental-approval
branches — pending approvals, denied access, supervised minors. Under adults-only those stop
mattering almost entirely, and one status becomes the whole point: **a platform telling us the
account holder is a verified adult is exactly what an eligibility gate wants**, and it is a
better-sourced statement than a date somebody typed.

1. If the platform tells us the holder is an adult, does that satisfy more of Q-A4's standard than a
   self-declared date does?
2. If the signal is unavailable or withheld — which is the default — may we fall back to Q-A4's
   self-declaration, or does the absence itself carry a consequence for a service that admits only
   adults?
3. Is there any risk in *receiving* this signal that we do not have today by not asking for it?

> **Default encoded:** none. No platform age API is called and no dependency for one has been added.
> **What changes:** where the eligibility answer comes from. The stored column is the same either way.

---

### Q-A6 · *Acceso* and *cancelación*: is what we can hand over, and what we can erase, enough?

Two halves, and the second is the sharpest item in this brief.

**The export half.** The app's privacy screen names one function: **`Pedir mi archivo`** — "request
my file". *Verified 2026-08-29:* it is drawn and deliberately inert — a card with no button and copy
saying the file cannot be assembled yet, so the screen promises nothing it cannot do. We do not know
whether the *acceso* right obliges us to provide an export at all for this kind of data, and if it
does:

1. **In what form?** A machine-readable file? A human-readable summary? The player's answered
   exercises are the bulk of it and are not meaningful to a person outside the app.
2. **Within what term?**

**The erasure half, and this is the one to spend time on.** `DELETE /me` erases the `players` row and
everything referencing it. **It does not erase the identity-provider account** — the email address,
the password hash and the account name survive a user asking us to delete their data, and they
survive because identity lives in the provider's own schema and this service holds no credential
that could remove it. That scope is written into the frozen contract rather than left implicit, and
it is disclosed to the user in the erasure screen's own copy before they confirm.

3. **Is a deletion that leaves the email address and the password hash standing a complete answer to
   a *cancelación* request**, given the user is told in advance that it is not?
4. If it is not, is the obligation on us to build a path that reaches the provider, or is the correct
   answer to tell the user how to close the account at the provider themselves?

> **Default encoded:** an emailed export, over the same email path the deletion flow already
> requires — recorded as a default, not decided. And a partial erasure, disclosed.
> **What changes:** if no export is owed, one feature disappears. If one is owed, it acquires a
> deadline and a format. If sub-question 3 comes back "no", we owe a new integration.
> **Also open, and unbuilt:** the public deletion page that works without installing the app
> (`f3-deletion-web`).

---

### Q-A7 · Are 400 days and 30 days defensible for an adult's data, and where must the policy be written?

*Verified 2026-08-29.* The system retains **exercise attempts for 400 days** and **diagnostic events
for 30 days**, then deletes them automatically. Both figures live in exactly one module and a test
keeps them there.

**The figures have not moved. Their justification has.** The 400 was chosen so that *a child*
returning after a year still has their progress; it is now so that *a player* does. The 30 is a
debugging window and was never about the audience. **Neither number was derived from a rule about
children's data**, which is why the decision does not obviously change either one — but it does
remove the reason we assumed they had to be conservative.

1. **Are those periods defensible** for an adult's data under Mexican law, given the stated purposes?
2. **Where must the retention policy live?** We verified that the amended United States COPPA Rule
   requires the retention policy — purposes, business need, deletion timeframe — to be written **into
   the privacy notice itself, and that linking to a separate document is not sufficient**
   (*verified, §6*). **That comparator has now lost most of its force**: COPPA is a children's rule,
   we do not launch in the US, and "build to the stricter of the two" was an argument that only made
   sense while we were building a children's product. So the placement question has to stand on its
   own feet: **does Mexican law say where the retention policy must appear?**
3. **The session rows have no period at all, and this is the question the decision did not touch.**
   The identity provider records an IP address and a user-agent for every sign-in. Our retention job
   sweeps only our own tables and does not touch those rows. Does that data need a retention period;
   if so, is setting it our obligation or the provider's; and does the fact that we cannot configure
   the provider change the answer?

> **Default encoded:** 400 days and 30 days, enforced by an automated job. The figures are published
> on no user-facing surface today, because the page that would carry them is unbuilt. No period at
> all for the session rows.
> **What changes:** two numbers in one module, possibly where the text sits, and possibly a third
> figure with nowhere to enforce it.

---

### Q-A8 · Who else holds this data, and what does each of them require?

Two external relationships, and neither is an email provider:

- **The database host.** Every datum in §3.1 sits in one hosted Postgres database run by a
  third-party provider. It is not a copy sent to a processor; it is where the data lives.
- **The identity provider**, a managed authentication service running inside that same database. It
  holds the email address, the password hash, the account name and a session row per sign-in
  carrying an IP address and a user-agent. We do not control the last of those — see §3.1.

**No transactional email provider has been chosen**, deliberately, because the choice has a legal
dimension we would rather take advice on than make on price. It is still needed for the
deletion-confirmation link.

**The old brief's third sub-question asked whether any of this changes when the address belongs to a
child. That sub-question is dead** — no minor may hold an account, so no minor's address is
collected. The rest of the question is untouched by the decision:

1. What must the contract with each of these contain, and does the database host need the same
   instrument as a processor that receives a copy?
2. **Nearly every provider in this market is hosted in the United States or the European Union**, and
   ours is. What does that make of the transfer, and what must the privacy notice say about it? *This
   was one sub-question among four and it is now among the two or three most consequential things in
   the brief, because with the child questions gone the transfer is what is left.*
3. Is there a reason to prefer a Mexican provider, for any of the three, that we are not seeing?

> **Default encoded:** none for email — no provider chosen. The database host and the identity
> provider are chosen and in use, which makes those two a review rather than a decision.
> **What changes:** a vendor decision, possibly two contracts, and a paragraph of the notice.

---

### Q-A10 · The privacy notice and terms themselves — do you write them, or review ours?

The app needs an **aviso de privacidad** and **términos**, in Mexican Spanish. *Verified 2026-08-29:*
neither exists, and the settings screen deliberately draws no row for either, because a row to an
empty page is worse than an absent one.

**The child-facing version of the notice is no longer a question.** What replaces it is smaller and
newer:

1. **Do you author these, or do you review a draft we produce?** The answer changes who does the work
   and when.
2. **What must the notice and the terms say about eligibility** — that the service is for adults, on
   what basis we determine that, and what happens if we learn otherwise? That last clause is Q-A13,
   and it has to be drafted before it can be built.

We would rather these be written for this specific app than adapted from a template, because §3.1's
inventory is unusually short and a template would describe collection we do not do.

---

### Q-A11 · A minor can still install the app and play it offline. Does that leave us anything?

**This is the survivor that surprised us, and it is the one question the adults-only decision makes
*more* pointed rather than less.**

ADR 0002 (2026-08-19) removed guest synchronisation outright, so there is no path by which an
unlinked device reaches our server. That answered the *design* question and it has never answered
the legal one. The adults-only decision does not answer it either — it closes the account door and
leaves the front door open, because **no age check stands in front of play** (§1, verified).

So: a ten-year-old installs AkiMath, plays it every day, and generates a record of everything they
have answered — on their own phone, in storage our software created, in a shape our software chose,
and none of it ever reaches us.

1. **When software we distribute processes a person's data entirely on their own device and transmits
   none of it, are we a controller of that data at all?** We can see the argument both ways: nothing
   reaches us, but we wrote the software that creates and stores it.
2. **Does a privacy notice have to be shown to someone who plays entirely offline and gives us
   nothing?**
3. **New, and created by the decision:** our terms will say the service is for adults. A minor
   playing offline is then using it contrary to those terms while causing us to hold nothing. Does
   that combination create any duty — to prevent it, to detect it, or to say something about it in
   the notice — that we would not have if the terms were silent?

**We are not asking you to endorse the design.** It is what the app does. What we need is whether a
device that never contacts us still owes anything, and whether saying "adults only" while doing
nothing to enforce it at the point of play is better or worse than saying nothing at all.

---

### Q-A12 · What may we keep about somebody we refused? *(new)*

**This question did not exist before**, because the old design refused nobody — a device below the
threshold was routed onward into a consent flow rather than turned away.

*Verified 2026-08-29.* Today the screen a below-threshold device reaches collects **nothing**: it
says that creating an account needs a parent's permission, that play continues on the phone, and
offers one control, which goes back. Under adults-only that screen becomes a refusal, and a refusal
raises a question a routing decision did not:

1. **May we record that a refusal happened, and if so what may the record contain** — a timestamp?
   the declared date? a device identifier? nothing?
2. **Must we?** As written, a refused person simply enters a different date and is admitted. A gate
   with no memory is a gate that can be walked around on the second attempt, and we cannot tell
   whether that is a defect we are obliged to fix or a privacy property we should be protecting.
3. If we may keep such a record, note that **we would be creating personal data about a person we
   have just declined to serve** — which feels like the wrong direction, and is exactly why we are
   asking rather than choosing.

> **Default encoded:** nothing is recorded. There is no server contact of any kind at the point of
> refusal, so there is nowhere for a record to go without building one.
> **What changes:** at most one table that does not exist. At least nothing.

---

### Q-A13 · An account holder turns out to be under 18. Then what? *(new)*

**Also new.** Under the old design this person was entitled to be there, with a parent's consent.
Under this one they are not, and terms that state an age limit with nothing behind them may be worth
less than terms that state none.

1. **On learning that an account holder is under 18 — however we learn it — what must we do?**
   Terminate the account? Delete the data? Both, and on what timeline?
2. Does the answer differ depending on how we learn it: the person tells us, a parent tells us, or we
   infer it?
3. Is there an obligation to *look*, or only to act on what arrives?

> **Default encoded:** nothing. There is no detection, no reporting channel, and no termination path
> other than the erasure the user can perform themselves.
> **What changes:** possibly a channel, possibly a procedure, and a clause in the terms Q-A10 covers.

---

## 5 · What we are *not* asking

Stated so no time is spent on them:

- **Parental consent, in any form.** Dead with Q-A3. No minor may hold an account, so there is
  nothing to consent to and no evidence to keep.
- **Google Play's Families programme, and parental gates.** Dead with Q-A9. An adults-only app is not
  in that programme. What age rating and what declarations the stores require of an adults-only app
  is a store-policy question for `f3-store-artifacts`, and we are not spending your time on it.
- **A child-facing version of the privacy notice.** Dead with Q-A10.
- **Advertising, analytics, tracking, profiling for marketing.** None exist and none are planned.
- **Content moderation, reporting flows, blocking.** No user produces content another user sees.
- **Payments, subscriptions, in-app purchases.** Not in this version.
- **Employment, tax or corporate structure.**
- **Trademark.** The name and mascot are a separate matter, not this one.
- **United States compliance.** We do not launch there. COPPA appears above only as a comparator we
  once chose to build to voluntarily, and Q-A7 now asks explicitly whether it still has any bearing.

---

## 6 · The legal landscape as we currently understand it — with our confidence marked

**Please correct anything here.** We researched it to make the questions specific, not to reach
conclusions, and we are aware that a non-lawyer reading statutes is how confident errors are made.

**The order changed with the audience.** Rows 1 to 4 used to be background and are now the whole
frame; row 3 is the single most load-bearing open item in this table, because the adult-data
obligations we now care about live in the Reglamento rather than in the law. The rows that only ever
mattered because of children are marked retired and kept, so that a reader of the superseded brief
can see they were considered rather than quietly dropped.

| # | What we believe | Confidence |
|---|---|---|
| 1 | A **new** LFPDPPP was published in the DOF on **20 March 2025** and took effect **21 March 2025**, repealing the 2010 law of the same name. | **Verified** against the Cámara de Diputados' published text and multiple Mexican firms' notes. |
| 2 | **INAI was dissolved**, and data-protection competence over private parties moved to the **Secretaría Anticorrupción y Buen Gobierno**. | **Verified**, same sources. |
| 3 | The decree gave the Executive **90 calendar days** to adapt the regulations. **We do not know whether the 2011 Reglamento was replaced, amended, or left standing** — and several obligations we care about live in the Reglamento rather than the law. | **Open question, and now the most important line in this table.** With the child questions gone, what is left is ordinary controller obligation — notice content, ARCO procedure, transfer — and that is Reglamento territory. One line on what is in force would change how several answers below are framed. |
| 4 | **An adult's personal data is personal data**, and holding an email address, a password hash, a session IP address and a play history for an identified natural person is processing that the LFPDPPP governs. | **Assumed** — but it is the premise the entire brief rests on, so if it is wrong, correct it first and stop reading. |
| 5 | The age at which a person may consent to the processing of their own data, and the age of civil-law majority, are the **same age** in Mexico. | **Assumed, and unverified.** Underlies Q-A1. Note that the old brief's version of this line was about *parental* consent and carried a warning that the phrasing may have reached us from **Spanish** law rather than Mexican; that warning still applies to anything we say about minors, which is now only Q-A11. |
| 6 | A specific consent age of **14** appears in commentary we found. **We believe this is Spain's LOPDGDD threshold and not Mexico's**, and we have not encoded it. | **Believed inapplicable** — kept because it is the kind of number that gets adopted by accident, and Q-A1 is choosing a number. |
| 7 | The amended US **COPPA Rule** requires a written retention policy stating purposes, business need and deletion timeframe, **incorporated into the privacy notice itself rather than linked**. | **Verified** — and **largely retired.** It bound nobody here even as a children's rule, since we do not launch in the US, and with the product adults-only the "build to the stricter of the two" argument that justified following it has gone. It survives in Q-A7 only as the reason we knew to ask *where* the policy must sit. |
| 8 | **Google Play Age Signals API**: worldwide by end of 2026, age ranges not birth dates, off by default, parent-controlled via Family Link. | **Verified** against Google's developer blog, July 2026. Underlies Q-A5, whose relevance went **up** with the decision. |
| 9 | **Apple Declared Age Range API**: parent-set range, shared only with permission, no birth date, already expanding beyond the US. | **Verified** against Apple Developer news, 2026. Underlies Q-A5. |
| 10 | **Google Play Families policy** applies to us in every market. | **Retired.** It was written when the app was child-directed, survived a first correction when the app became general-audience, and does not survive this one: an adults-only app is not in the Families programme. What the stores require of an adults-only app is a store question, not a legal one — see §5. |

**Sources consulted**

- [LFPDPPP, texto vigente — Cámara de Diputados](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf)
- [LFPDPPP, texto original DOF 20 mar 2025](https://www.diputados.gob.mx/LeyesBiblio/ref/lfpdppp/LFPDPPP_orig_20mar25.pdf)
- [Reglamento de la LFPDPPP](https://www.diputados.gob.mx/LeyesBiblio/regley/Reg_LFPDPPP.pdf)
- [BASHAM — nueva LFPDPPP publicada en el DOF](https://basham.com.mx/en/nueva-ley-federal-de-proteccion-de-datos-personales-en-posesion-de-los-particulares-publicada-en-el-diario-oficial-de-la-federacion/)
- [EY México — entrada en vigor de la nueva LFPDPPP](https://www.ey.com/es_mx/technical/tax/boletines-fiscales/nueva-ley-federal-proteccion-datos-personal-posesion-particulares)
- [Greenberg Traurig — nueva ley de protección de datos](https://www.gtlaw.com/en/insights/2025/3/nueva-ley-general-proteccion-de-datos)
- [Android Developers Blog — Play Age Signals API](https://android-developers.googleblog.com/2026/07/google-play-age-signals-api-safer-experiences.html)
- [Apple Developer — age requirements for apps](https://developer.apple.com/news/?id=f5zj08ey)
- Retired with row 7, kept for the record: [Fenwick — the amended COPPA Rule and data retention](https://www.fenwick.com/insights/publications/what-the-amended-coppa-rule-means-for-data-retention-practices) · [Finnegan — COPPA's amended Rule in full effect](https://www.finnegan.com/en/insights/articles/coppas-amended-rule-is-now-in-full-effect-what-operators-need-to-know.html)

---

## 7 · Where each answer lands

For our own tracking. Counsel does not need this section.

**Shipped** means merged and, where it touches the database, applied to the live one. A shipped row
does not mean the question is closed; it means the answer now changes something that exists rather
than something drawn. Status verified 2026-08-29 by reading the code, except where a row cites a
count, which is 2026-08-26 and carried forward.

| Question | Becomes | In | Status |
|---|---|---|---|
| Q-A1 eligibility age | one named constant | the auth screens | **Shipped at the wrong value.** `AgeGate.consentAge = 13`, in one place; the adults-only change moves it to 18 |
| Q-A2 what is recorded about age | the `age_band` values, and whether a date may be stored | `f1-schema-freeze`, the auth screens | **Shipped and frozen.** A `CHECK` constraint with three values, one live row using `adult` |
| Q-A4 assurance mechanism | the age-gate screen | the auth screens | **Shipped.** Neutral date entry, reduced to a band on the device, the date discarded |
| Q-A5 platform age signal | where the eligibility answer comes from; possibly a dependency, which needs its own review | the auth screens, `f3-store-artifacts` | **Not started.** No platform age API is called |
| Q-A6 *acceso* and *cancelación* | one feature kept or dropped; possibly an integration with the identity provider | the profile settings, `f3-deletion-web` | **Half built, and disclosed as half built.** `Pedir mi archivo` is inert; `DELETE /me` runs and does not reach the identity provider |
| Q-A7 retention | two numbers in one module; a third that has nowhere to live; text placement on the public page | `f1-schema-freeze`, `f3-deletion-web` | **Half shipped.** The job runs nightly on 400 and 30; the figures appear on no user-facing surface; the session rows are swept by nothing |
| Q-A8 processors and transfer | a vendor and up to three contracts | `f3-deletion-web` | **Two in use, one not chosen.** No email provider, and none is needed until the deletion page exists |
| Q-A10 notice and terms | two published documents, plus their URLs in the compliance inventory | `f3-store-artifacts` | **Not started**, and the settings rows that would point at them are deliberately absent |
| Q-A11 offline minors | possibly nothing; possibly a notice shown to someone who gives us nothing | ADR 0002, the first-run flow | **Live and unexamined.** It is what the app does today |
| Q-A12 refused users | at most one table that does not exist | the auth screens | **Nothing recorded**, by construction — there is no server contact at the point of refusal |
| Q-A13 an ineligible holder | a channel, a procedure and a clause | `f3-store-artifacts`, the terms | **Not started.** No detection and no termination path |

**Retired from this table:** Q-A3 (consent evidence — the columns stay permanently unbuilt) and Q-A9
(parental gate — no interstitial will be built). Both are recorded in §2 rather than deleted, so a
reader of the superseded brief can see they were answered by the decision rather than forgotten.

---

## 8 · Status

**Reopened by the fourth tripwire on 2026-08-26, and rewritten by the adults-only decision on
2026-08-29.** The 2026-08-16 deferral and its four tripwires are recorded verbatim in the superseded
brief; they are summarised here rather than repeated, because that document is where the
word-for-word record belongs.

### The tripwires, restated for an adults-only service

The original four were written to describe a children's harm. Three of them named a child; that was
the right reading then and it is the wrong one now, because the people whose data we hold are all
adults and none of them has a privacy notice to read.

| # | The original tripwire | Status | Restated |
|---|---|---|---|
| 1 | The app reaches **any child** outside this household | **Not crossed** as of 2026-08-26, on Ervin's own word | **Any person** outside this household holds an account. That is the line now: an adult with an account and no *aviso de privacidad*, no public deletion route and no export is the harm, and it does not require a child |
| 2 | A TestFlight or Play internal-test build goes to anyone outside the household | **Not crossed** — no build has been distributed | Unchanged, and it is the mechanism by which tripwire 1 gets crossed |
| 3 | Any store submission, even unlisted | **Not crossed** | Unchanged |
| 4 | The server exists and holds a real person's row | **MET.** The schema went up 2026-08-17; the first real row appeared 2026-08-21 | Unchanged, and still met |

### The judgement, stated exactly

**The adults-only decision is a real reduction and it is not a release.**

What it genuinely removes: the parental-consent machinery and every column it would have created;
the Families-programme surface and the parental gate; the child-facing notice; and the whole class of
question that begins "does this change when the subject is a child". Those were the heaviest items in
the old brief by engineering cost and by review risk, and they are gone rather than deferred.

What it does not touch, in the plainest terms available:

- **The identity-provider account survives our erasure path.** A person who asks us to delete their
  data keeps an email address and a password hash at the provider. Adults have that right too.
- **Every sign-in records an IP address and a user-agent, under no retention period we set.** We
  cannot switch it off. The old brief could at least say no minor's IP was recorded; that mitigation
  survives and it never covered the adults, who are now everybody.
- **There is no *aviso de privacidad* and no *términos*.** Neither document exists. The app draws no
  row pointing at them, because a row to an empty page is a worse lie than an absent one.
- **There is no public deletion page**, so the only erasure route requires installing the app.
- **A minor can still install the app and play it offline**, and whether that leaves us anything is
  Q-A11, which the decision sharpened rather than settled.

The tripwire that describes the harm is still uncrossed: nobody outside this household has the app.
*That is the one claim in this section taken on Ervin's word rather than read off the system* — the
repository can show that two verified addresses existed on 2026-08-26 and cannot show whose they
are. Marked the way §6 marks its assumptions, because it is the sentence the rest of this judgement
rests on.

The shape of the exposure, in one line, unchanged from 2026-08-26: **the data sits with a third-party
database host, while the server process that reads it has only ever run on a development machine.**
The storage is real and off-premises; the service is not yet anywhere.

**None of the above is a legal conclusion; it is a statement of what the system is doing**, offered
so counsel is answering about a system that runs rather than one on paper.

- [x] Brief written — 2026-08-16, as a children's-data brief
- [x] Deferred — 2026-08-16, personal use, tripwires above
- [x] Tripwire 4 met — the server holds a real person's row as of 2026-08-21; recorded 2026-08-26
- [x] Rewritten for an adults-only product — 2026-08-29; the children's version is superseded and
  kept as history
- [ ] Counsel engaged
- [ ] Consult held
- [ ] Answers recorded below

### Answers

*Recorded here as they arrive, one heading per question, quoting counsel rather than paraphrasing.
Until this section is filled, every default above is an assumption and is labelled as one.*
