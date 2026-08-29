# Open decisions

Things the code is currently doing one way, that nobody has decided should be done that way.

Each entry says what the code does **today**, why that was the safe interim, and what would change.
They are here rather than in a change ledger because a ledger is archived when its change merges,
and an undecided thing that gets archived becomes a decided thing nobody remembers taking.

---

## 1 · The keypad offers two keys the answer contract cannot accept

**Today.** `KeypadLayout.item` ships a decimal key (`,`) and a square key (`²`) because the design
draws them. The frozen canonical answer shape is `-?digits` optionally over `digits`, which admits
**neither**. `AnswerDraft` therefore refuses both characters, so pressing either does nothing.

**Why that is the interim.** Before the refusal, one tap on either produced a draft that `grade`
could only ever score **wrong** — two keys of sixteen that punished a child for the app's own gap,
with `canSubmit` returning true for a draft of nothing but `,`. A key that does nothing is bad; a key
that guarantees a coral verdict is worse.

**What has to be decided.** Either the contract grows a decimal answer shape — which is a
`packages/contract` change, a new golden vector, and a Dart canonicaliser change to match — or those
two keys come off the item pad, which is a design change. **Both are outside a session's authority**:
the first alters a frozen artifact, the second alters a drawn screen.

**Cost of leaving it.** Low today: no item in `starter.json` needs either key. It rises the moment
content wants a decimal answer, and at that point the interim reads as a bug rather than a decision.

**Found by:** the bug hunt of 2026-08-16.

---

## 2 · A streak of zero is shown as a zero

**Today.** The home always renders the streak pill. On a fresh install it reads `0`.

**Why that is the interim.** The plan says the streak pill ships on the F2 home and does not say
"hide it at zero". Inventing a hide-at-zero rule would be inventing design, and a pill that appears
only sometimes changes the layout of the screen it sits on.

**What has to be decided.** Whether a zero streak should show as `0`, be hidden, or say something
else. It is the first thing a new player sees, and `0` beside a mascot asking whether they want to
practise is a slightly deflating opening.

**Cost of leaving it.** Cosmetic, and only on the first run — one completed series makes it a `1`.

---

## 3 · `MathTone` and `MasteryLevel` value sets are grounded but not drawn

**Today.** `MathTone` has one member, `ink`, because that is all the corpus grounds — a second was
inferred, had no producer, and was removed when a review found the adapter arm behind it
unreachable. `MasteryLevel` has four, taken from the skill map's own legend, and all four arms are
exercised.

**What has to be decided.** Nothing urgent. Recorded so that the next person to add a member does it
because a digest asked, not because a switch looked lonely.

---

## 4 · `StreakPolicy` lives under `round/`, the plan puts it under `home/`

**Today.** `features/round/policy/streak_policy.dart`. The plan's component inventory files it under
`home/`, alongside `DayLogStore`.

**Why.** Both features use it: the round records a day, the home displays the count. Moving it would
make one of them import across a feature boundary either way, and the churn buys nothing today.

**What has to be decided.** Whether to follow the plan and take the cross-feature import, or amend
the plan. Worth settling before a third consumer appears.

---

## 5 · The teaching item wears the series' header

**Today.** `0.3 Primer reto` composes `RoundScreen`, so it inherits the whole item shell — including
`Reto 1` in the middle and `Nivel 1` on the right.

**Why that is the interim.** Composing the round is the point: a second solve screen would be a
second place to keep the keypad, the answer slot and the verdict in agreement.

**And the cost is now lower than this entry first recorded.** It said suppressing the header would
mean a third parameter on a shared widget. It would not: the skip control was removed from one-item
rounds by deriving it from `items.length`, and the header could be derived the same way — a round of
one has no series to count and no ladder to place the player on. That makes this a question about what
the tutorial should *say*, which is still design's, rather than a question about what it would cost.

**What has to be decided.** Whether the tutorial should show them at all. `Reto 1` counts a series of
one, and `Nivel 1` names a ladder step on the one screen where the player has no ladder yet — D11
kept `0.4` out of F2 precisely so nothing would promise a level this build cannot adapt to, and a
static `Nivel 1` is a milder version of the same claim. Against that: it is the same header the very
next screen shows, so hiding it makes the tutorial teach a shell the app does not have.

**Cost of leaving it.** Cosmetic, and visible only on the first run.

**Found by:** the Tier 2 pass of 2026-08-17, on the simulator. No test could see it — the design
gates assert overflow and shadows, not what the chrome claims.

---

## 6 · `0.2` is a bespoke column, and the plan assigns it `CenteredStateView`

**Today.** `features/onboarding/ui/welcome_screen.dart` is a `Padding` around a `Column`. It draws
Aki, a bubble, one line of body copy and one primary action.

**What the plan says.** `docs/IMPLEMENTATION-PLAN.md` §4.0 gives `CenteredStateView` to
`f2-onboarding-first-run` with `0.2` as its first consumer, and §3.3 counts **11 screens** for it —
`4.8`–`4.10`, `4.12`–`4.15`, `0.2`, `0.4`, `0.6`, `0.7`. The approved proposal for that change never
mentioned it, and neither does the code. The component does not exist.

**Why that is defensible today.** The plan's own promotion test is *two features and no domain
vocabulary*, and exactly one screen needs this shape. Building an 11-screen abstraction from one call
site is how a component acquires parameters nobody drew — the plan itself warns that naming
compositions as widgets is what turns a 53-row inventory into a 130-row one.

**Cost of leaving it.** The second screen of this shape — `0.4`, `0.6`, `0.7` or any of `4.8`–`4.15` —
either forks the column or extracts the component then. Extracting from two real call sites is
cheaper and more honest than guessing from one. **The risk is not the fork, it is the silence:** the
plan says a change built this and it did not, so this entry exists to stop the next reader trusting
§4.0's table over the tree.

**What has to be decided.** Nothing yet. The first change that draws a second centred state view
either extracts `CenteredStateView` or records why not, here.

---

## 7 · ~~Tier 2 cannot be driven from a session~~ — RESOLVED 2026-08-17

**Today.** Device evidence is captured by rooting `main.dart` at the screen under test, building for
the iPhone 17 simulator, and screenshotting with `xcrun simctl io`. That reaches anything **static**.
It cannot reach anything that needs a **touch**: this machine gives `osascript` no assistive access
(`-1719`), `simctl` has no tap operation, and `idb` is not installed. A synthetic
`PointerDownEvent` through `GestureBinding` drives the pressed state under `flutter test` and has no
effect in the device build.

**What it blocks, concretely.** `f0-pressable-surface` 5.3 and `f0-keypad` 3.3 — *"confirm the travel
reads as sinking rather than sliding"* and *"the keys travel"*. Both are the same missing capability,
and both are the interaction language of ~50 drawn elements, so they are not cosmetic. The resting
geometry of every control **is** evidenced (`f0-pressable-surface/evidence/controls-resting.png`).

**The options, and neither is a session's call.**
1. **A human taps.** Free, immediate, and unrepeatable — it closes these two tasks and nothing later.
2. **`integration_test`.** A dev dependency plus a `test_driver/` entry point; real taps, real device,
   screenshots through the driver, and it keeps working for every future Tier 2. It is out of scope of
   the runtime allowlist by design (DEP-1 governs what *ships*), but it is new tooling and belongs in
   its own change rather than smuggled into whichever one hits the wall first — which is how it nearly
   got added twice already, on 2026-08-17.

**Resolved: option 2.** `integration_test` is in, as a dev dependency, and
`app/integration_test/playthrough_test.dart` drives a fresh install from the welcome screen through
the teaching item, the home, a five-item series of real pack content and the summary, on an actual
simulator — real asset bundle, real `shared_preferences` plugin, real renderer. Thirteen seconds.

It exists because Ervin asked whether the app could be watched playing itself, which is the same
question this entry had been holding open. `f0-pressable-surface` 5.3 and `f0-keypad` 3.3 are now
reachable: a press a machine can perform is exactly what they were waiting for.

Two things the first run found, both of which a written observation would have missed. A real device
is slower than a widget test and the first-run flag is written asynchronously, so one
`pumpAndSettle` is not enough to reach the home — it settles with a budget now. And the fourth item
of the shipped series is `sub-2`, whose answer is `−7`: the minus key's id is `negate` and the
fraction bar's is `fraction`, neither of which is the character on the key face. Any driver that
assumed otherwise would have worked on four items out of five.

---

## 8 · No document states an app-store age rating

**Today.** Nothing anywhere declares one. A sweep of `docs/`, `openspec/` and `app/` before this
entry was written found no passage naming an age rating, a content-rating questionnaire answer, or
an IARC tier — not in `f3-store-artifacts`, which owns the Data Safety declaration and the privacy
manifest, and not in either Gate A brief. The product became **adults-only** on 2026-08-29
(`docs/adr/0004-the-game-is-for-adults.md`) and an adults-only product has a rating to declare, so
this is a **gap rather than a stale value**: there is no wrong answer written down to correct.

**Why that is the interim.** It was nobody's until 2026-08-29. Before then the audience was mixed
and the store question was folded into Google Play's Families programme, which the adults-only
decision retires — `docs/gates/gate-a-adult-data-consult.md` §5 marks that assumption retired and
says plainly that what the stores require of an adults-only app is a **store** question rather than
a legal one. Retiring the question it was inside of is what left it with no owner, and the sibling
plan that swept for it recorded it as a gap it could not fill.

**Who owns it.** Ervin, researching it separately as of 2026-08-29. That is recorded here rather
than as an answer because it is what was said, and no date, target tier or deliverable has been
named. Do not infer one.

**What it does not block.** Not the refusal, and not this decision's shape. `docs/adr/0004`'s
amendment §1 chose **Reading A** — the app asks at link time and refuses there — so the app makes
its own claim whatever the store says. The option that *did* depend on a rating is the one where
the store declares eligibility and the app does not ask, and the sibling plan's `design.md` D3
already showed that option is unavailable precisely because no rating exists. It stays unavailable
until this entry closes.

**Cost of leaving it.** Zero today and a hard stop at the first submission: neither store lets an
app through without a content rating, so this closes before anything ships or nothing ships. The
sharper risk is subtler — a rating declared in a console by whoever happens to be submitting,
recorded nowhere, contradicting `req-no-remote-messaging` or the Data Safety rows
`f3-store-artifacts` will assert. **Whatever the answer is, it lands in a file this repository can
read**, which is the whole reason it is written down here.

**Found by:** the sweep that carried ADR 0004's answers into the documents, 2026-08-29.
