# The app-store age rating — a proposal

**Status:** proposed, 2026-08-29. Answers task 0.5 of `openspec/changes/the-game-is-for-adults/`,
which recorded that **no document anywhere states the app-store age rating**. Nothing here is
legal advice, and nothing here has been exercised against a real store submission — there is no
deployed application and no store account.

## The distinction that decides everything

Both stores ask **two separate questions**, and conflating them is the trap:

| | what it asks | AkiMath's answer |
|---|---|---|
| **Content rating** | what is *in* the app | the lowest tier. It is arithmetic, number series and a dog. |
| **Eligibility / target audience** | who the app is *for* | adults only (ADR 0004) |

An adults-only policy does **not** come from answering the content questionnaire dishonestly. Both
stores have a field for exactly this case, and using it is the whole proposal.

## Apple

The rating system was overhauled in 2025. The tiers are now **4+, 9+, 13+, 16+, 18+** — the old
12+ and 17+ are gone. The relevant sentence from Apple's own announcement:

> If your app has a policy requiring a higher minimum user age than the rating assigned by Apple,
> you can set a higher age rating after you respond to the age ratings questions.

That is AkiMath's case precisely. **Answer the content questionnaire honestly — it will land at or
near 4+ — and then set the rating to 18+ as the policy minimum.**

Two notes. Ratings are assigned **per country or region** and may vary. And the deadline to answer
the updated questions was **2026-01-31**; it is moot for an app that has never been submitted,
which simply meets the current questionnaire on its first submission.

**On iOS, 18+ is a rating and not a gate.** Apple does not stop an under-18 from downloading it.
The in-app refusal is what carries the policy there.

## Google Play

Three fields, and the third is the one worth having.

1. **Content rating** — the IARC questionnaire is mandatory for every app. AkiMath lands at
   *Everyone*.
2. **Target audience** — the age groups are *5 and under · 6–8 · 9–12 · 13–15 · 16–17 · 18 and
   over*, and multiple selections are allowed. Select **18 and over, and nothing else.**
3. **Restrict Minor Access** — available *only* to apps targeting 18 and over exclusively. With it
   enabled, users Google identifies as under 18 **cannot search for, download or purchase the
   app**. Existing users keep access but cannot renew a subscription or make a new purchase.

**This is the finding that matters, and it is better than the decision assumed.** ADR 0004 records
that a self-declared date of birth is a legal posture rather than a technical barrier. That stays
true on iOS. On Android it stops being true: Restrict Minor Access is enforcement the *store*
performs, against the age on the Google Account, before the app is ever installed — a barrier we
neither build nor operate, sitting in front of the one we do.

## What it costs

- **Families and kids surfaces are gone.** Intended, and already true as of ADR 0004.
- **Discovery.** An 18+ mathematics game is an unusual object, and neither store's ranking is
  documented well enough to say what it does to reach. This is a real product cost and is named
  rather than estimated.
- **Purchases**, if there are ever any: an existing minor user keeps access and loses the ability
  to buy. There is no in-app purchase today, so this costs nothing now.

## What is not verified

- Google's help page says *"certain apps are required to enable"* Restrict Minor Access without
  naming the categories. Whether AkiMath is one of them is unknown and does not change the
  proposal, since the recommendation is to enable it voluntarily.
- Nothing here was verified against Mexico-specific store behaviour, and Apple varies ratings by
  region.
- No store account exists, so none of the above has been seen in a real console.

## Proposal

| store | content rating | eligibility |
|---|---|---|
| Apple | answered honestly, expected 4+ | **set to 18+** as the policy minimum |
| Google Play | IARC, expected *Everyone* | **target audience 18 and over only**, and **enable Restrict Minor Access** |

The in-app refusal built at link time stands regardless — on iOS it is the only barrier, and on
Android it is the second one.

## Sources

- [Updated age ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf) — Apple Developer
- [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159) — Play Console Help
- [Content rating requirements](https://support.google.com/googleplay/android-developer/answer/9859655) — Play Console Help
