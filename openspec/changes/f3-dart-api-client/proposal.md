# The app can call the server

## Why

`GET /me` has worked since `f3-the-first-endpoint`, and nothing could call it. ADR 0001 decided
`app/lib/api/` is hand-written and it is an F3 directory; not a line of it existed.

Everything server-side over the last several changes was verified by me, with `curl` and a local
key server. This is the first time any of it is exercised by the client that will actually ship.

## What changes

- **`api/me.dart`** — the frozen `Me`, immutable, with an `AgeBand` enum so a `switch` over the
  band is exhaustive.
- **`api/api_client.dart`** — one operation, `getMe`, returning a sealed `MeResult`. A PURE-2
  adapter holding no decisions: no retry, no caching, no token storage.
- **`test/api/contract_parity_test.dart`** — the client half of R2. The server has
  `contract-parity.test.ts`; nothing compared `contract/openapi.json` to the Dart side.
- **No new dependency.** `dart:io`'s `HttpClient`, because AkiMath is mobile and the runtime list
  stays at `flutter`, `cupertino_icons`, `meta`, `shared_preferences`.

## Out of scope

The other seven operations. Each is a method and a result type when it lands, the same way
`IMPLEMENTED_OPERATIONS` prunes itself server-side. A client with seven methods that all 501 is
seven pieces of untested code.

The account flow. This slice needs a token from somewhere and does not care where.
