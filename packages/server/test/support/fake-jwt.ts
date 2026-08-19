/**
 * A JWT-shaped string, built rather than written down.
 *
 * **No test in this package holds a token literal**, and the reason is a secret
 * scanner: gitleaks reads a hardcoded three-part base64url string as
 * `generic-api-key`, and it is right to — nothing in the bytes distinguishes a
 * fixture from a credential. The alternatives were an inline `gitleaks:allow`
 * or an allowlisted path, and both work by teaching the scanner to look away
 * from exactly the files most likely to grow a real one.
 *
 * Constructing it is also more honest about what it is: three base64url runs,
 * the first decoding to a JOSE header. Nothing here signs anything —
 * `session-verifier.test.ts` mints real tokens with a real Ed25519 key.
 */
const b64url = (value: unknown): string =>
  Buffer.from(JSON.stringify(value)).toString("base64url");

export function fakeJwt(
  options: { readonly claims?: Record<string, unknown>; readonly signature?: string } = {},
): string {
  const header = b64url({ alg: "EdDSA", typ: "JWT" });
  const payload = b64url(options.claims ?? { sub: "abc" });
  const signature =
    options.signature ?? Buffer.from("not-a-real-signature").toString("base64url");
  return `${header}.${payload}.${signature}`;
}
