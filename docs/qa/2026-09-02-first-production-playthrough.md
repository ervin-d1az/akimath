# The first playthrough against a deployed server

**2026-09-02, iOS simulator (iPhone, 402×874 pt) against `akimath-api` on Fly and Neon.**

The offline loop closed end to end for the first time: a pack was issued, five items were
played, the batch reached `POST /attempts`, the server graded them by digest, and `HISTORIAL`
drew `Restas · 2 sep · 5/5`. Everything below is what the walk found on the way, in the order
it cost time.

Evidence is the deployed server's own log lines and the Neon tables, not a test double.

## 1. `POST /packs` races `POST /players/link`, and the 404 is terminal

On the launch where the account is created, the home asks for a pack before the link has
landed. The player row does not exist yet, so issuing answers 404 — and nothing ever retries.

```
02:52:17.602  POST /packs         404  ms:679
02:52:17.624  POST /players/link  200  ms:716
```

The device then plays the **bundled** pack for the rest of the process. A bundled item names no
server pack, so nothing it produces is syncable: a full five-item series left `attempts` at 0
and produced **no request at all** after the link.

**The cost is a permanent divergence, not a delay.** Perfil now reads `10 RETOS / 90 % ACIERTOS`
and `attempts` holds exactly five rows. The device counted ten challenges; the server can never
learn about five of them, because those five were answered against a pack it never issued and
`attempts` takes no UPDATE. Every figure derived from the two will disagree for the life of the
account.

**The mechanism is a trigger, not a missing `await`.** Both requests started within ~15 ms of
each other, and `_askForPack` in `home_route.dart:324` guards on `session == null` — it reacts
to *the session appearing*. Linking reacts to the same event. So the fix is not to await the
link on a sequential path; it is that the home must wait for a linked **player**, which is a
different fact from a live session.

It recovers only by relaunching — with the player row already there, `POST /packs` answered
`200` in 324 ms. So the endpoint is fine; the ordering is not.

The client already has the right shape for this elsewhere: `pack_refresh.dart` reads a 404 from
`GET /packs/{id}` as *ask for a new one*. A 404 from `POST /packs` has no such reading.

## 2. The access token is never refreshed inside a process

`LinkedSession.accessToken` is minted once and `provider` is null for every session the running
app builds — `session.dart` says so in as many words. The provider cookie **is** on disk, and
`session_restore.dart` already mints a fresh token from it at launch. Nothing does that
mid-process.

```
03:29:05  POST /players/link  200  caller:session     (token minted at launch)
03:49:30  POST /attempts      401  caller:refused     (same token, 20 min later)
```

The token was good at 03:29 and refused at 03:49, so the lifetime is **under twenty minutes** —
that is what was measured; the provider's exact default was not. **A player who plays longer
than that stops syncing until they restart the app**, with nothing on screen to say so.

The attempt journal behaved correctly: a refused session is *kept*, and the batch flushed on the
next launch — `POST /attempts 200`, five rows, one `session_id`, real `elapsed_ms`. The journal
is not the defect; it is what keeps the defect from losing data.

## 3. `GET /me/history` is fetched once, before the flush it depends on

Same lineage as #1. On the launch that flushed the batch, history was asked and answered before
the attempts landed:

```
03:51:04.581  GET  /me/history  200   (empty)
03:51:04.697  POST /attempts    200   (five rows land)
```

Perfil therefore drew **no `HISTORIAL` section** while the server held the session. Only the
next relaunch showed it. Nothing re-reads history after a sync lands.

## 4. The invented figures are behind one switch, and the switch is on

Two different series — one 4/5 with an arithmetic, an analogy, a figurate, a function machine
and a matrix; one 5/5 from the issued pack — printed **identical** numbers:

- `+ 12 RATING`
- `QUÉ MEJORÓ · Fracciones 68 % · Multiplicar 96 %`

Neither series contained a fraction or a multiplication item, and F2's decision is that a
verdict surface shows **no rating** — `GET /me/standing` answers per skill, so no single number
over a list of Glicko ratings is a fact about a player.

**This is not scattered fakery and the fix is one line.** Every one of these figures comes from
`lib/demo/demo_figures.dart`, which the summary screen names *"the one quarantined home for an
invented figure"*, and all of them are drawn behind `DemoFigures.enabled` — whose own comment
reads *"A build that flips this to false shows only what the product can prove, which is what
shipping looks like."* It is `true` at `demo_figures.dart:83`, including in the build installed
against production. `0.7`'s `1 248 RATING` is the same source, so it is one fix and not two.

## 5. `Empezar la serie` sits below the fold — a judgement, not a measurement

The home's primary action is last in the column, after `ROMPECABEZAS` — one card per puzzle the
pack carries, five today — and `HOY JUEGAS`. On a 402×874 device the screen opens with no
visible way to start the thing it is asking for; it takes a scroll. The comment above it reads
*"Last, so nothing sits below the thing the screen is asking for"*, which was true when the
list was shorter. `screen_overflow_test.dart` cannot see this: the column scrolls, so it does
not overflow.

Unlike 1–4, this one is a reading rather than a measurement — somebody put the button last on
purpose and said why. It is here because the reason no longer holds, not because the code is
wrong.

## A question raised and closed

The issued pack was played at indices **5–9**; items 0–4 were never shown, because the cursor
had already advanced five during the bundled-pack series and carried across to a different
pack. The cursor is indeed per-device — `series_cursor_store.dart` keys it
`akimath.items_served.v1`, with no pack in the key.

**It is not a defect.** `seriesIndices` generates positions modulo the pack length, so it can
never ask for an index the pack does not have, and the opening items are not stranded: they are
played when the cursor wraps — the seventeenth series, for an eighty-item pack served five at a
time. A deferral, not a loss, and carrying the cursor across packs is what keeps a player from
replaying the same opening every time a pack is reissued.

## What was **not** a defect

The rating calibrated rather than moved, and that is by design. Every class the five items hit
had no prior evidence, so `playerOutcomes` stayed empty: `user_skills` and `session_deltas` are
0, `difficulty_ratings` holds **3** measured classes, and the history entry's `ratingDelta` is
null — which is exactly what a session that only calibrated is supposed to report. A second
series now has something to be measured against.

(Difficulty classes are written to `difficulty_ratings`, not `template_stats`; the latter being
empty says nothing.)
