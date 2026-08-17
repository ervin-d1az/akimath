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
