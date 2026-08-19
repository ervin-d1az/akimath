# The session is a bearer JWT, and the contract says so

## Why

Every operation in `contract/openapi.json` declares `401 — No valid session`. Nothing in the
document says what a session *is*, where it travels, or what a client should attach. There is no
`securitySchemes` block and no `security` requirement anywhere — checked, not assumed.

That is the decision the handler would otherwise make by accident. Someone writes the first
authenticated endpoint, reads a header, and the contract acquires an auth mechanism nobody
declared and no client was told about.

It is also the last thing standing between here and a real endpoint. `POST /players/link` now
carries what its row needs; what it does not have is a way to know who is asking.

## What changes

- `securitySchemes.session` — `http` / `bearer` / `JWT`, described.
- `security: [{ session: [] }]` **at the document root**, so an operation is authenticated unless
  it says otherwise, and a test that nothing says otherwise.
- A gate tying the two artifacts together: **every operation the contract secures is refused by
  `route()` without a credential**, and the one route outside the contract answers.

## Out of scope

Verifying the token. That needs a JWKS fetch, a dependency and its DEP-1 audit, and it is the next
change. This one settles what arrives, not what happens to it.
