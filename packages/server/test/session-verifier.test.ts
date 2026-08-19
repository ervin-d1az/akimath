import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK } from "jose";
import { beforeAll, describe, expect, it } from "vitest";

import { createSessionVerifier, type SessionVerifier } from "../src/adapters/session-verifier.js";

const ISSUER = "https://ep-example-123456.us-east-1.aws.neon.tech";
const USER = "3f1a2b4c-0000-7000-8000-00000000abcd";

let sign: (claims: Record<string, unknown>, options?: { issuer?: string; expiresIn?: string }) =>
  Promise<string>;
let signWithAStrangeKey: () => Promise<string>;
let verify: SessionVerifier;

/**
 * **A real Ed25519 key pair, and no network.** `createLocalJWKSet` has the same
 * `JWTVerifyGetKey` shape `createRemoteJWKSet` returns, so the verifier under
 * test is the production one with its key source swapped — the signature check
 * is real, the expiry check is real, and only the HTTP fetch is absent.
 *
 * That the algorithm is EdDSA is not a detail: it is what Neon Auth signs with,
 * and a verifier configured for RS256 would reject every genuine token. This
 * suite would fail if the runtime could not do Ed25519 at all.
 */
beforeAll(async () => {
  const { privateKey, publicKey } = await generateKeyPair("EdDSA", {
    crv: "Ed25519",
    extractable: true,
  });
  const stranger = await generateKeyPair("EdDSA", { crv: "Ed25519", extractable: true });
  const jwk = (await exportJWK(publicKey)) as JWK;
  jwk.kid = "test-key";
  jwk.alg = "EdDSA";

  sign = async (claims, options = {}) =>
    new SignJWT(claims)
      .setProtectedHeader({ alg: "EdDSA", kid: "test-key" })
      .setIssuedAt()
      .setIssuer(options.issuer ?? ISSUER)
      .setExpirationTime(options.expiresIn ?? "15m")
      .sign(privateKey);

  signWithAStrangeKey = async () =>
    new SignJWT({ sub: USER })
      .setProtectedHeader({ alg: "EdDSA", kid: "test-key" })
      .setIssuedAt()
      .setIssuer(ISSUER)
      .setExpirationTime("15m")
      .sign(stranger.privateKey);

  verify = createSessionVerifier(createLocalJWKSet({ keys: [jwk] }), ISSUER);
});

describe("turning a header into a caller", () => {
  it("a good token becomes a session carrying the subject", async () => {
    const token = await sign({ sub: USER });
    expect(await verify(`Bearer ${token}`)).toEqual({ kind: "session", userId: USER });
  });

  it("no header is absent, not refused", async () => {
    expect(await verify(undefined)).toEqual({ kind: "absent" });
  });

  it("a header that is not a bearer token is refused before any crypto runs", async () => {
    const caller = await verify("Basic dXNlcjpwYXNz");
    expect(caller.kind).toBe("refused");
  });

  it("an expired token is refused", async () => {
    // Neon issues 15-minute access tokens, so this is the ordinary case rather
    // than the exotic one: every client will hit it several times an hour.
    const token = await sign({ sub: USER }, { expiresIn: "-1s" });
    const caller = await verify(`Bearer ${token}`);
    expect(caller.kind).toBe("refused");
    expect(caller.kind === "refused" && caller.why.toLowerCase()).toContain("exp");
  });

  it("a token from another issuer is refused", async () => {
    // The check that stops a valid token from someone else's Neon project — or
    // from any other Better Auth deployment — being accepted here.
    const token = await sign({ sub: USER }, { issuer: "https://someone-else.example" });
    expect((await verify(`Bearer ${token}`)).kind).toBe("refused");
  });

  it("a token signed by a key we do not have is refused", async () => {
    // Same `kid`, different key: this is what an attacker who has read the
    // header format but not the private key can produce.
    expect((await verify(`Bearer ${await signWithAStrangeKey()}`)).kind).toBe("refused");
  });

  it("a token with no subject is refused, because there is nobody to be", async () => {
    // A signed, unexpired, correctly-issued token with no `sub` verifies
    // cryptographically and identifies no one. Accepting it would put `undefined`
    // where a user id belongs.
    const token = await sign({});
    const caller = await verify(`Bearer ${token}`);
    expect(caller.kind).toBe("refused");
    expect(caller.kind === "refused" && caller.why).toContain("sub");
  });

  it("garbage in the bearer position is refused rather than thrown", async () => {
    // The verifier is on the request path. An exception here is a 500 for a
    // request that deserves a 401.
    for (const token of ["not.a.jwt", "abc", "..", "eyJhbGciOiJub25lIn0..".repeat(3)]) {
      expect((await verify(`Bearer ${token}`)).kind).toBe("refused");
    }
  });

  it("no refusal ever quotes the token back", async () => {
    // Refusal reasons are logged and returned. A token in one of them is a
    // credential written to a log file, which is the whole reason this is a
    // test rather than a habit.
    const token = await sign({ sub: USER }, { expiresIn: "-1s" });
    const reasons = [
      await verify(`Bearer ${token}`),
      await verify(`Bearer not.a.jwt`),
      await verify(`Bearer ${await signWithAStrangeKey()}`),
    ]
      .map((caller) => (caller.kind === "refused" ? caller.why : ""))
      .join(" ");

    expect(reasons.length).toBeGreaterThan(0);
    expect(reasons).not.toContain(token);
    expect(reasons).not.toContain("not.a.jwt");
  });
});
