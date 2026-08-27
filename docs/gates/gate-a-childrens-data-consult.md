# Gate A — consult brief: children's data protection

**For:** a lawyer specialised in personal-data protection in Mexico, with children's data experience.
**From:** Ervin Diaz, AkiMath.
**Opened:** 2026-08-16.
**What we need back:** a short written answer per numbered question, cited by number. Not a memo.
Eleven questions, each with the answer we have assumed written underneath it — several may be
confirmable in a sentence.

**Nothing in this document is legal advice, and nothing in it should be read as our legal position.**
It is an engineering plan's list of open questions, each stated with the default the plan currently
encodes so that your answer is a one-line change rather than a redesign. Where we cite a statute we
mark whether we verified it or inherited it as an assumption; treat the unverified ones as questions
too.

---

## 1 · Why this is time-boxed

The database schema freezes in the next phase of work and does not get edited afterwards — after
that point a column is added by a new forward-only migration, never by changing the one that made it.
Four of the eleven questions below — Q-A1, Q-A2, Q-A3 and Q-A7 — decide a column, a constraint or a
named constant in that schema. The rest decide a screen, a vendor or a document, all of which are
cheaper to change later.

Concretely: this consult blocks one change (`f1-schema-freeze`), which blocks every change in phase
F3 — the server, the sync path, the deletion path and the app-store compliance artifacts. It is the
only thing on the project's critical path whose input comes from outside the codebase.

**A useful turnaround is two to three weeks.** Nothing is on fire; there is no launch date. We would
rather wait for a correct answer than build on a guess, which is why the questions are written to be
answerable without reading any code.

---

## 2 · The product, in the detail that matters here

**AkiMath** is a mobile app (iOS and Android) that gives a child adaptive arithmetic challenges in
Mexican Spanish, with a dog called Aki as the mascot. Markets for the first version: **Mexico and
Spanish-speaking Latin America. No United States launch.** The audience explicitly includes children
under 13.

**One thing to be clear about before you read further: almost none of this is built yet.** There is
no database, no server, no account system and no published app. Everything in §2.1 describes a
schema that has been designed and is about to be frozen — not a system that is running and holding
anyone's data today. That is precisely why we are asking now: we can still change a column for the
cost of a sentence. Where this document says a setting "is switched off" or a column "does not
exist", read it as *designed that way and not yet deployed*.

What the app is *not*, because each absence removes a category of obligation and you should not have
to ask:

- **No advertising, of any kind.** No ad SDK, no ad network, no sponsored content.
- **No third-party analytics, no crash reporting, no attribution SDK, no A/B testing service.** This
  is enforced in the codebase, not merely intended: the app ships with three runtime dependencies,
  none of which makes a network call.
- **No social features.** No chat, no friends, no sharing, no user-generated content, no leaderboard.
- **No display name and no username.** The database has no column for one. A child never types a name
  and no other user ever sees anything a child produced.
- **No photos, no camera, no microphone, no location, no contacts, no device advertising identifier.**
- **No push-notification service.** Reminders are scheduled locally on the device, so there is no
  push token and no messaging provider.
- **No payments in the first version.**
- **Offline first.** The first playable version has no server at all. The child plays against a file
  bundled in the app; nothing leaves the phone.

The app is therefore intentionally close to collecting nothing. The questions below are almost all
about the small amount it does collect once accounts exist, and about the paperwork that accompanies
it.

### 2.1 What is collected, in full

This is the complete inventory as designed. Nothing else is planned.

| Datum | Where it comes from | Why | Retained | Shared with |
|---|---|---|---|---|
| `player_id` — a random UUID | Generated on the device at first launch | The only identifier for a player's progress; it is not derived from the device or the person | Until deletion | Nobody |
| `age_band` — one of a small set of ranges | Derived on the device from a date the user enters; **the date itself is discarded and never transmitted** | To route the consent flow and to know which protections apply | Until deletion | Nobody |
| Email address | Typed by the user when creating an account | Sign-in, and the deletion-confirmation link | Until deletion | The transactional email provider — see Q-A8 |
| Password hash | Derived from a password the user chooses | Sign-in | Until deletion | Nobody |
| `attempts` — one row per exercise answered: which item, what was typed, whether it was right, when | The child's own play | Adaptive difficulty and the child's own progress view | **400 days** — see Q-A7 | Nobody |
| `user_skills` — a numeric skill rating per topic | Computed from attempts | Choosing the next exercise's difficulty | Until deletion | Nobody |
| `diag_events` — a row noting which misconception an error matched | Computed from attempts | To improve the explanations the app gives | **30 days** — see Q-A7 | Nobody |
| `offline_packs` — which exercises were downloaded for offline play | The server | To re-verify offline answers when the device reconnects | Until expiry or deletion | Nobody |

Two deliberate design choices worth naming, because they narrow the questions:

- **The child's own answers are never sent to other players and never leave our own database.** There
  is no path by which one child's data reaches another.
- **IP address and user-agent logging is switched off** in the authentication library, which persists
  both by default.

Everything above is deleted by a single erasure path, available both inside the app and from a public
web page that works without installing the app.

---

## 3 · The questions

Each question states **the default the plan currently encodes**. In several cases confirming the
default is the whole answer.

---

### Q-A1 · Is 13 the wrong number?

The plan uses a **single named constant** for the age at or above which a person may consent for
themselves, and below which a parent or guardian must consent. Its default value is **13**, chosen as
the floor the United States' COPPA sets, on the reasoning that a rule built for 13 is at least as
protective as one built for a lower number.

**The question is whether Mexican law makes 13 the wrong constant** — in particular whether the fact
that a *minor* in Mexican civil law is anyone under 18 means parental consent is required for the
whole under-18 population rather than only the under-13 one.

> **Default encoded:** 13.
> **What changes if you say otherwise:** one constant, and the shape of Q-A2's bands. Nothing else.
> **What we need:** the number, and if it is not a single number — if the rule is graduated by age —
> the graduation.
> **Premise we could not verify:** that a parent-or-guardian consent duty attaches at all in the
> form we describe — §5, line 5. If that line is wrong, this question may not have the shape we
> have given it.

---

### Q-A2 · Are these the right age bands?

The app stores a band, never a birth date. The default set is:

```
under_13 · 13_17 · 18_plus
```

**Is this set adequate, and does it need to be finer?** If, for example, an obligation attaches at 14
or 16, the set needs a boundary there.

> **Default encoded:** three bands as above.
> **What changes:** an enumerated type in the database and one screen's options.
> **Note:** both mobile platforms are converging on four bands — under 13, 13–15, 16–17, 18+ — see
> Q-A5. If there is no legal reason to prefer three, matching the platforms may be free.

---

### Q-A3 · When a parent or guardian consents, what must we collect, and what must we keep as proof?

This is the question with the largest engineering consequence, because the answer becomes database
columns and we cannot add them later without a migration.

Two distinct things:

1. **What the flow must collect** in order for the consent to be valid — an email address for the
   adult? a confirmation the adult acts on? something more?
2. **What we must retain as evidence** that consent was given — and for how long, and in what form.

We would prefer to store the minimum that constitutes valid evidence, since every field we keep about
an adult is a field we then have to protect and delete. **We do not want to collect a parent's
government identification, a payment instrument, or a signature** unless you tell us one is required.

> **Default encoded:** none. The plan deliberately leaves this open rather than guessing, because a
> guess here is a schema we would have to change.
> **What changes:** columns in the schema, and a screen that has not been designed yet — so an answer
> now costs nothing and an answer later costs a migration.
> **Premise we could not verify:** §5, line 5 — the existence and wording of the verification duty
> this question assumes. If no such evidence must be retained, the answer is "collect nothing" and
> the columns never exist.

---

### Q-A4 · Is a self-declared date, reduced to a band on the device, adequate age assurance?

The app asks for a date of birth in a neutral field — not a leading *"¿eres mayor de 13 años?"*,
which invites the answer that unlocks the app. The date is converted to a band **on the phone** and
the date itself is then discarded; only the band is ever transmitted.

We chose this because it collects strictly less than storing a birth date. **Is it enough?**

We had understood there to be an obligation to make *reasonable efforts* to verify that a consent
genuinely comes from the person holding parental authority — but **we could not confirm that this
duty exists in Mexican law in that form** (§5, line 5; we may have read Spanish law by mistake). So
the question is really two:

1. **Does such a verification duty exist here at all**, and in what words?
2. If it does, does a self-declared date reduced to a band satisfy it for an app of this size — and
   does the duty attach to the age declaration, to the consent, or to both?

> **Default encoded:** neutral date entry, reduced on device, date discarded.
> **What changes:** if a stronger mechanism is required, it is a new screen and possibly a processor.

---

### Q-A5 · Does a platform-supplied age range change the answer to Q-A4? *(new since the plan was written)*

Both app stores now offer to tell the app the user's age *range*, set by a parent, shared only if the
parent allows it, and without ever disclosing a birth date:

- **Google Play Age Signals API** — announced for worldwide rollout by the end of 2026, so it reaches
  Mexico. Age ranges are not shared by default; parents control them from Family Link. Google's
  developer guidance states that an account-creation flow using it must handle every status:
  verified adults, supervised minors, pending parental approvals, denied access, and self-declared
  ages. *(Verified via Google's developer blog, July 2026 — see §5.)*
- **Apple Declared Age Range API** — already live and expanding beyond the United States. Parents set
  a range; it is shared only with their permission; no birth date is involved. *(Verified, §5.)*

This is genuinely new relative to our written plan, which had set platform age APIs aside on the
grounds that they were a United States requirement and we are not launching there. That reasoning
still holds for the *statutory* obligations, but the *platform* mechanism is arriving in our markets
regardless.

**The questions:**

1. If a parent has told the platform the child's age range and the platform tells us, does that
   satisfy more of the verification duty than a self-declared date does?
2. If the parent declines to share it — which is the default — may we fall back to Q-A4's self-
   declaration, or does declining itself carry a consequence?
3. Is there any risk in *receiving* this signal that we do not have today by not asking for it?

> **Default encoded:** none — the plan predates the worldwide rollout.
> **What changes:** where the band comes from. The column is the same either way, which is why this
> can be answered after Q-A1 through Q-A3 if time is short.

---

### Q-A6 · Do we owe the child a copy of their data, and in what form?

The app has one function on its privacy screen: **`Pedir mi archivo`** — "request my file". We do not
know whether the *acceso* right obliges us to provide an export at all for this kind of data, and if
it does:

1. **In what form?** A machine-readable file? A human-readable summary? The child's answered
   exercises are the bulk of it and are not meaningful to a person outside the app.
2. **Within what term?**
3. **To whom, when the account holder is a child?** The child, the consenting adult, or either?

> **Default encoded:** an emailed export, sent over the same email path the deletion flow already
> requires — recorded as a default, not decided.
> **What changes:** if no export is owed, one feature disappears. If one is owed, it acquires a
> deadline and a format.
> **Related:** deletion is already built and is not in question — it is available in the app and from
> a public web page that requires no install, and it erases everything in §2.1.

---

### Q-A7 · Are 400 days and 30 days defensible, and where must they be written?

The plan retains **exercise attempts for 400 days** and **diagnostic events for 30 days**, then
deletes them automatically. The 400 is chosen so that a child returning after a year still has their
progress; the 30 is a debugging window.

**Two questions:**

1. **Are those periods defensible** for children's data under Mexican law, given the stated purposes?
2. **Where must the retention policy live?** We verified that the amended United States COPPA Rule
   requires the retention policy — purposes, business need, deletion timeframe — to be written
   **into the privacy notice itself, and that linking to a separate document is not sufficient**
   (*verified, §5*). COPPA does not bind us, since we do not launch in the US. **Does Mexican law
   impose the same "in the notice, not linked" placement?** We would rather build to the stricter of
   the two once than discover the difference later.

> **Default encoded:** 400 days and 30 days, enforced by an automated job, with the figures published
> on the public deletion page and read from the same source the job reads, so the promise and the
> job cannot drift apart.
> **What changes:** two numbers in one module, and possibly where the text sits.

---

### Q-A8 · The email provider will receive children's — and parents' — email addresses. What does that require?

Account sign-in and the deletion-confirmation link both need transactional email. That provider is
the **only** external company that will ever hold any personal data of ours, and we have not chosen
one yet — deliberately, because the choice has a legal dimension we would rather take advice on than
make on price.

1. What must the contract with that provider contain?
2. **Nearly every provider in this market is hosted in the United States or the European Union.** What
   does that make of the transfer, and what must the privacy notice say about it?
3. Does any of this change when the address belongs to a child rather than to a parent?
4. Is there a reason to prefer a Mexican provider that we are not seeing?

> **Default encoded:** none. No provider chosen.
> **What changes:** a vendor decision and a paragraph of the notice.

---

### Q-A9 · Does leaving the app to read a legal document need a parental gate?

The account-creation screen carries the line *"Al crearla aceptas los términos y el aviso de
privacidad."* Those two documents will be web pages, and tapping them opens the phone's browser. We
deliberately rejected showing them in an embedded browser inside the app, because that amounts to
putting an unrestricted browser inside a child-directed app.

Google Play's Families policy restricts what a child-directed app may do when it sends a user out of
the app. **Does opening a legal document in the browser require a parental gate** — the "ask an adult
to solve this" interstitial — **or are legal documents exempt?**

> **Default encoded:** no gate.
> **What changes:** one interstitial screen. This is the cheapest question in the list and we ask it
> only because it is cheaper to ask now than to be told by a store review.

---

### Q-A10 · The privacy notice and terms themselves — do you write them, or review ours?

The app needs an **aviso de privacidad** and **términos**, in Mexican Spanish, written for an audience
that includes children. That is authoring work, not a configuration value, and it is the one Gate A
item with no default in the plan.

Two sub-questions:

1. **Do you author these, or do you review a draft we produce?** The answer changes who does the work
   and when.
2. Is a **child-facing version** — the same notice written so a nine-year-old can read it — required,
   advisable, or neither?

We would rather these be written for this specific app than adapted from a template, because §2.1's
inventory is unusually short and a template would describe collection we do not do.

---

### Q-A11 · Please price the alternative that removes the question

Before you answer Q-A1 through Q-A5, we would like this option costed, because it may make most of
them moot:

> **Below the consent threshold, offer no account at all.** The child plays as a guest with
> synchronisation switched off. There is no email address, no account and no server record; the
> exercises answered are written to the phone's own storage and never transmitted.

**We do not know whether that puts us outside the regime, and we are not assuming it does.** The
question, stated as neutrally as we can:

1. **When an app we distribute processes a child's data entirely on the child's own device and
   transmits none of it, are we a controller of that data at all?** We can see the argument both
   ways — nothing reaches us, but we wrote the software that creates and stores it.
2. If we *are* still a controller, does the answer to Q-A1 through Q-A5 apply unchanged to a child
   who never creates an account?
3. Does a privacy notice have to be shown to someone who plays entirely offline and gives us nothing?

**This is more urgent than its position in the list suggests.** The first playable version of the app
works exactly this way — offline, no account, no server — and it is scheduled to exist *before* the
schema this consult unblocks. **If local-only processing carries obligations, they attach to that
build**, and we would need to know before it reaches anyone rather than after.

We are not asking you to recommend the option as a permanent design. It costs the under-13 audience
their progress across devices and their adaptive difficulty — most of what the product does — so
whether to adopt it is a business decision. But if it is legally clean, it is worth knowing what we
are buying with the complexity of the alternative.

---

## 4 · What we are *not* asking

Stated so no time is spent on them:

- **Advertising, analytics, tracking, profiling for marketing.** None exist and none are planned.
- **Content moderation, reporting flows, blocking.** No user produces content another user sees.
- **Payments, subscriptions, in-app purchases.** Not in this version.
- **Employment, tax or corporate structure.**
- **Trademark.** The name and mascot are a separate matter, not this one.
- **United States compliance.** We do not launch there. COPPA appears above only as a design floor we
  chose to build to voluntarily, and Q-A7 asks explicitly whether the Mexican rule differs.

---

## 5 · The legal landscape as we currently understand it — with our confidence marked

**Please correct anything here.** We researched it to make the questions specific, not to reach
conclusions, and we are aware that a non-lawyer reading statutes is how confident errors are made.

| # | What we believe | Confidence |
|---|---|---|
| 1 | A **new** LFPDPPP was published in the DOF on **20 March 2025** and took effect **21 March 2025**, repealing the 2010 law of the same name. | **Verified** against the Cámara de Diputados' published text and multiple Mexican firms' notes. |
| 2 | **INAI was dissolved**, and data-protection competence over private parties moved to the **Secretaría Anticorrupción y Buen Gobierno**. | **Verified**, same sources. |
| 3 | The decree gave the Executive **90 calendar days** to adapt the regulations. **We do not know whether the 2011 Reglamento was replaced, amended, or left standing** — and several obligations we care about live in the Reglamento rather than the law. | **Open question.** We would value one line on what is currently in force. |
| 4 | The new law reinforces protections for minors and invokes the *interés superior de la niñez*. | **Assumed** from secondary commentary, not read in the statute. |
| 5 | Consent for a minor's data must come from a parent or guardian, and the controller must make **reasonable efforts** to verify it does. | **Assumed** — and note this phrasing may have reached us from **Spanish** law rather than Mexican. Our search returned Spain's LOPDGDD alongside Mexican sources and **we could not reliably separate them.** This directly underlies Q-A1, Q-A3 and Q-A4, so it is the single most important line in this table to correct. |
| 6 | A specific consent age of **14** appears in commentary we found. **We believe this is Spain's LOPDGDD threshold and not Mexico's**, and we have not encoded it. | **Believed inapplicable** — flagged because it is the kind of number that gets adopted by accident. |
| 7 | The amended US **COPPA Rule** was published **22 April 2025**, took effect **23 June 2025**, and full compliance was required by **22 April 2026** — a date now past. It requires a written retention policy stating purposes, business need and deletion timeframe, **incorporated into the privacy notice itself rather than linked**. | **Verified.** Relevant only as the voluntary floor described in Q-A7 — we do not launch in the US. |
| 8 | **Google Play Age Signals API**: worldwide by end of 2026, age ranges not birth dates, off by default, parent-controlled via Family Link. | **Verified** against Google's developer blog, July 2026. Underlies Q-A5. |
| 9 | **Apple Declared Age Range API**: parent-set range, shared only with permission, no birth date, already expanding beyond the US. | **Verified** against Apple Developer news, 2026. Underlies Q-A5. |
| 10 | **Google Play Families policy** applies to us in every market because the app is child-directed, independently of which data-protection statute governs. | **Assumed.** Underlies Q-A9. |

**Sources consulted**

- [LFPDPPP, texto vigente — Cámara de Diputados](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf)
- [LFPDPPP, texto original DOF 20 mar 2025](https://www.diputados.gob.mx/LeyesBiblio/ref/lfpdppp/LFPDPPP_orig_20mar25.pdf)
- [Reglamento de la LFPDPPP](https://www.diputados.gob.mx/LeyesBiblio/regley/Reg_LFPDPPP.pdf)
- [BASHAM — nueva LFPDPPP publicada en el DOF](https://basham.com.mx/en/nueva-ley-federal-de-proteccion-de-datos-personales-en-posesion-de-los-particulares-publicada-en-el-diario-oficial-de-la-federacion/)
- [EY México — entrada en vigor de la nueva LFPDPPP](https://www.ey.com/es_mx/technical/tax/boletines-fiscales/nueva-ley-federal-proteccion-datos-personal-posesion-particulares)
- [Greenberg Traurig — nueva ley de protección de datos](https://www.gtlaw.com/en/insights/2025/3/nueva-ley-general-proteccion-de-datos)
- [Fenwick — what the amended COPPA Rule means for data retention](https://www.fenwick.com/insights/publications/what-the-amended-coppa-rule-means-for-data-retention-practices)
- [Finnegan — COPPA's amended Rule now in full effect](https://www.finnegan.com/en/insights/articles/coppas-amended-rule-is-now-in-full-effect-what-operators-need-to-know.html)
- [Android Developers Blog — Play Age Signals API](https://android-developers.googleblog.com/2026/07/google-play-age-signals-api-safer-experiences.html)
- [Apple Developer — age requirements for apps in Brazil, Australia, Singapore, Utah, Louisiana](https://developer.apple.com/news/?id=f5zj08ey)

---

## 6 · Where each answer lands

For our own tracking. Counsel does not need this section.

| Question | Becomes | In |
|---|---|---|
| Q-A1 threshold | one named constant | `f1-schema-freeze`, `f3-auth-screens` |
| Q-A2 bands | the `age_band` enumerated type | `f1-schema-freeze` |
| Q-A3 consent evidence | columns, and a screen not yet designed | `f1-schema-freeze`, design request DR-7 |
| Q-A4 assurance mechanism | the age-gate screen and `req-age-gate` | `f3-auth-screens` |
| Q-A5 platform age signal | where the band comes from; possibly a dependency, which needs its own review | `f3-auth-screens`, `f3-store-artifacts` |
| Q-A6 export right | one feature kept, dropped, or given a deadline | `f7-profile-settings`, design request DR-P3 |
| Q-A7 retention | two numbers in `retention.ts`; text placement on the public page | `f1-schema-freeze`, `f3-deletion-web` |
| Q-A8 email provider | a vendor and a contract | `f3-deletion-web` |
| Q-A9 parental gate | one interstitial, or nothing | `req-legal-reachable` |
| Q-A10 notice and terms | two published documents, plus their URLs in the compliance inventory | `f3-store-artifacts` |
| Q-A11 the alternative | a product decision, taken by Ervin with this input — **and, if local-only processing carries obligations, a constraint on the offline build that ships before F1** | `f2-core-loop` |

---

## 7 · Status

**Reopened by the fourth tripwire — recorded 2026-08-26.** The deferral written on 2026-08-16 is kept
below word for word, because it is the reason every default in this document is labelled as a default
and because what it asserted is exactly what stopped being true. Its premise has expired. The risk it
was protecting against has not yet arrived. Both halves matter and neither one is the other.

### The deferral, as recorded on 2026-08-16

**Deferred, deliberately — Ervin, 2026-08-16.** The app is for personal use for now. It is not
distributed, not in a store, and collects nothing from anyone: the first playable build has no
account, no network and no database at all (decision #2). Nothing in §2.1 exists as a running system,
so there is no processing to be compliant about.

That makes this cheap to defer rather than a risk being carried. It also defers more than this gate:
`f1-schema-freeze` and every F3 change sit behind the same fact, and none of them is on the path to a
build you can play.

**What reopens it — any one of these, and this document is the first thing to pick up:**

- The app reaches **any child who is not in this household** — a niece, a nephew, a friend's kid, a
  classroom. That is the real line, and it is crossed by handing someone a phone, not by publishing.
  → **Not crossed**, as of 2026-08-26.
- A **TestFlight or Play internal-test build** goes to anyone outside the household. → **Not
  crossed** — no build has been distributed and `f3-store-artifacts` has not run.
- **Any store submission**, even unlisted. → **Not crossed.**
- **The server exists and holds a real person's row** — the moment `f1-schema-freeze` runs against a
  database that is not throwaway. → **MET.** The freeze ran against this database on 2026-08-17; the
  first real person's row appeared on 2026-08-21.

### What changed, verified against the running system on 2026-08-26

**§1, §2 and §2.1 are superseded on this point and should be read as they stood on 2026-08-16.** §1
says the schema "freezes in the next phase of work" — it froze, on 2026-08-17 — and that this consult
"blocks one change (`f1-schema-freeze`), which blocks every change in phase F3". §2 says in bold that
"almost none of this is built yet" and that "there is no database, no server, no account system and
no published app"; §2.1 presents its inventory "as designed". Where any of them disagrees with this
section, this section is later and this section is correct. The one clause of §2 that still holds
without qualification is **no published app**.

Taking the deferral's own clauses one at a time:

- **"no database at all"** — eight migrations are applied to the project's hosted Postgres database:
  the first two on 2026-08-17, the remaining six on 2026-08-21. `f1-schema-freeze` is merged and
  archived, and what that database is running is the schema it froze plus six forward-only
  migrations on top of it — which is the regime this document was written to get ahead of.
- **"no account"** — the authentication provider's tables in that same database hold **two accounts,
  each with a verified email address**, and seven sessions, all created on 2026-08-21. An email
  address is the one datum in §2.1 that reaches a third party at all — Q-A8 — and it now exists.
  Eight of the nine operations in `contract/openapi.json` have handlers, `POST /players/link`,
  `GET /me` and `DELETE /me` among them, so the account path and the erasure path are both written
  code rather than a plan.
- **"no network"** — the app opens sockets, in `app/lib/api/api_client.dart`. It fails closed rather
  than open: both endpoints are `--dart-define` values and are empty in any build nobody configured.
  But the path exists and a configured build takes it.
- **"Nothing in §2.1 exists as a running system"** — partly false, and the split is the useful part.
  `player_id`, `age_band` and `offline_packs` exist: **one `players` row**, band `adult`, created
  2026-08-21 and linked to an account, and **three `offline_packs` rows**, none of them yet expired.
  `attempts`, `user_skills` and `diag_events` are **all zero**. Nobody has answered a single exercise
  through the server.
- **"there is no processing to be compliant about"** — storing is processing, and there is now a
  scheduled deletion machinery on top of it. `.github/workflows/retention.yml` has run against that
  database and succeeded on nine consecutive nights, 2026-08-18 to 2026-08-26, under its own
  `retention_job` role — a role that exists in the database and holds DELETE on seven tables and
  nothing else. **It has never deleted anything**, because nothing has reached either deadline: there
  are no attempts and no diagnosis events at all, and the oldest offline pack expires 2026-09-20.
  Decision #3's 400 days and 30 days are no longer a recorded default; they are a job that runs and
  has so far had nothing to do. That posture is worth stating plainly for Q-A7 — the machinery is
  live and has not yet fired once.
- **"and every F3 change sit behind the same fact"** — nine F3 changes have merged and been archived:
  the server foundation, the session verification, the account link, the logging path and the app's
  API client. The two that have **not** run are `f3-deletion-web` and `f3-store-artifacts` — so
  §2.1's closing promise, that everything it lists "is deleted by a single erasure path, available
  both inside the app and from a public web page that works without installing the app", is the half
  still unbuilt while the database holds a row. `DELETE /me` exists; the public page does not.
- **"for personal use for now"** — **this clause still stands, and it is the only one that does.**

### The judgement, stated exactly

The fourth tripwire is met on its own words. The server exists; it holds a real person's row; the
database is not throwaway, and the project has already said so itself in refusing to point the test
harness at it. That is the tripwire, met, and this section is the record of it.

What is **not** crossed is the first tripwire, and the first tripwire is the one that describes the
harm. No child outside this household has reached the app. The single `players` row carries the
`adult` band and was created the same afternoon the schema went up; both accounts are Ervin's own.
**That last point is the one claim in this section taken on Ervin's word rather than read off the
system** — the repository can show that two verified addresses exist and cannot show whose they are.
Marked here the way §5 marks its assumptions, because it is the sentence the rest of this judgement
rests on.

So, precisely: not "we are non-compliant", and not "nothing has changed". The rationale for deferring
has expired while the risk it deferred has not yet arrived. What would make this urgent is short and
specific — any of the first three tripwires, all still uncrossed — and the first of them is crossed
by handing someone a configured build, not by publishing. What prevents that today is that nobody has
done it: there is no deployment, no store artifacts, and no distribution of any kind. That is absence
by omission, not by design. The shape of the exposure, said in one line: **the data sits with a
third-party database host, while the server process that reads it has only ever run on a development
machine.** The storage is real and off-premises; the service is not yet anywhere. **None of the above is a legal conclusion; it is a statement of what the
system is doing**, offered so counsel is answering about a system that runs rather than one on paper.

**Deferring is no longer free, which is the part that changed quietly.** The 2026-08-16 note ended
"nothing needs unpicking later — the threshold is one named constant, the bands are one enumerated
type". The threshold is still one named constant. The bands are now a `CHECK` constraint inside a
frozen, forward-only migration with a live row using one of them, so changing them costs a new
migration and a data migration rather than an edit. One correction while we are here: the frozen
schema spells the third band `adult`, not `18_plus` as Q-A2 shows. The boundaries are the ones Q-A2
states — only the label differs — and the question Q-A2 asks is unaffected.

Until counsel answers, the plan's recorded defaults still stand as defaults and are still labelled as
such wherever they appear, which is what §5's disclaimer was written to make possible. The difference
is that they are now defaults a running system has already adopted.

- [x] Brief written — 2026-08-16
- [x] Deferred — 2026-08-16, personal use, tripwires above
- [x] Tripwire 4 met — the server holds a real person's row as of 2026-08-21; recorded here 2026-08-26
- [ ] Counsel engaged
- [ ] Consult held
- [ ] Answers recorded below
- [ ] `f1-schema-freeze` — **not unblocked; it ran without this gate.** Merged 2026-08-17 and applied
  to a live database the same day, on this document's recorded defaults. Q-A1, Q-A2, Q-A3 and Q-A7
  now change a frozen schema and a row in it rather than an unwritten one.

### Answers

*Recorded here as they arrive, one heading per question, quoting counsel rather than paraphrasing.
Until this section is filled, every default above is an assumption and is labelled as one in the
plan.*
