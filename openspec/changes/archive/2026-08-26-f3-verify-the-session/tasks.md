## 1. Reading the header

- [x] 1.1 Red → green: absent, malformed and bearer, with the scheme case-insensitive.
- [x] 1.2 A token with a space is refused rather than truncated.

## 2. Verifying the token

- [x] 2.1 DEP-1 audit for `jose` before installing; recorded in the allowlist.
- [x] 2.2 Red → green against a real Ed25519 key pair: good, expired, wrong issuer, wrong key, no
      subject, not a JWT.
- [x] 2.3 No refusal quotes the token.

## 3. Configuration

- [x] 3.1 Issuer and JWKS URL from one variable; an explicit JWKS URL wins.
- [x] 3.2 Missing, unparseable or plaintext refuses startup rather than every request.

## 4. Answering

- [x] 4.1 `route()` takes a caller; 501 once authenticated, declared per operation.
- [x] 4.2 The 501 list is held to the router in both directions.

## 5. Evidence

- [x] 5.1 Tier 1 with counts.
- [x] 5.2 Tier 1b: mutation read and acted on — `session.ts` and `auth-config.ts` to 100.
- [x] 5.3 Tier 2: the real `main.ts` against a real JWKS over a socket.
