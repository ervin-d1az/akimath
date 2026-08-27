# Design

## D1 — `dart:io`, and the dependency floor stays at four

AkiMath is mobile — confirmed, not assumed. `app/` carries a `web/` directory because
`flutter create` left one, and there is no web build.

That settles the HTTP question: `dart:io`'s `HttpClient` costs nothing, where `package:http` would
be a fifth runtime dependency needing a DEP-1 audit. If web ever became a target this would not
compile — which is a loud failure at build time, not a silent one, so no gate is needed to protect
the decision.

## D2 — A sealed union, not exceptions

`getMe` returns one of five values and throws nothing. A screen cannot `catch` a call it did not
make, and a client that reports some outcomes by return and others by exception makes every caller
handle failure twice.

`MeNoPlayer` is deliberately not an error case. It is the ordinary state of an adult who has made
an account and not linked a device, and the screen for it is an invitation rather than an apology.

`MeUnreachable` is separate from `MeFailed` for the same reason the server separates
`unauthenticated` from `invalid_session`: "the server said no" and "there was no server" lead to
different next actions — one is a message, the other is a retry.

## D3 — The model is held to the artifact, in both directions

The server's `Me` check reads `contract/openapi.json`; so does this one. One direction alone is not
enough: "every required field is present" passes for a model that also carries three invented ones,
and "no invented fields" passes for a model missing two.

`createdAt` is the field that would have rotted quietly. The frozen pattern demands a literal `Z`
and allows an optional fraction; `DateTime.parse` also takes `+00:00`, a bare local time, and a
space where the `T` should be. Each of those round-trips to different bytes than it arrived as,
which is how two sides stop agreeing about an instant while every test still passes.

The model **re-derives** the rules rather than copying the frozen regular expression, because a copy
is a second source of truth. What keeps the re-derivation honest is running both over the same 19
probes and requiring them to agree on every one — including the four that only a real calendar
gets right: 29 February in 2028 and 2000 accepted, in 2025 and 1900 refused.

`playerId` is carried without validation, and the asymmetry is named in the test with its reason.
Parsing a date changes the value; an id is passed through, so an off-contract one is the server's
bug and refusing it here would turn a cosmetic defect into a client that cannot show a profile.

## D4 — Not a pure root, on purpose

`PureRoot` holds `design/**/spec/`, `features/*/policy/` and `content/model/`. Every one is *policy
that could plausibly reach for Flutter and must not*. `Me` is a data holder with a `fromJson`;
there is no Canvas or clock it could import by accident. Adding a fourth root would buy a gate over
three fields and cost a permanent entry in an enum whose value is that each member earned its
place.

## D5 — Tested against a real socket, then against the real server

No mocking library and no fake transport. `dart:io` gives `HttpServer.bind` for free, so the client
under test is the production one talking over a real socket — real headers, a real status line, a
real body. A fake `HttpClient` would have proved the client calls the fake correctly.

Then the whole slice, for real: the production `ApiClient` against the production `main.ts`, a real
Ed25519 JWT, and a real PostgreSQL row.

```
--- no player linked yet ---
good token             MeNoPlayer
expired token          MeRejected  tag=invalid_session  message="exp" claim timestamp check failed
--- after linking one ---
good token             MeFound  playerId=018f4e3c-…-0000000000e1 band=under_13 at=2026-08-19T18:08:21.762Z
```

## D6 — What running it for real found

A defect no unit test would have produced. `getMe('')` sent `Authorization: Bearer ` — a header the
server can only refuse, and it refuses it as `invalid_session`, "you sent something broken", when
the truth is `unauthenticated`, "you sent nothing".

The server had gone to the trouble of separating those two tags and the client was throwing the
distinction away on its first call. Fixed by sending no header at all for a blank token; the server
log now reads `caller=absent` where it read `caller=refused`.

## Known drift, not fixed here

`contract/openapi.json` declares `servers: [{ url: "/v1" }]`. The server mounts at `/`, and
**neither parity gate catches it** — the server's compares paths without the prefix, and this one
checks the model rather than the URL. So a client built strictly to the contract would ask for
`/v1/me` and get a 404 today.

The client therefore takes a whole base URL and appends `me` to it, which is correct against either.
Deciding which side moves is a change of its own, and it should land before anything is deployed.
