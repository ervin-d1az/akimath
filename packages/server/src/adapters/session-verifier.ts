import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";

import type { Caller } from "../routing.js";
import { readCredential } from "../session.js";

/**
 * Turns an `Authorization` header into a caller.
 *
 * **ADAPTER.** The parsing half is `src/session.ts` and is pure; this is the
 * half that holds a key set and can reach the network, and it is deliberately
 * thin — every decision it makes is either "the library said no" or one of the
 * two checks below.
 */
export type SessionVerifier = (header: string | undefined) => Promise<Caller>;

/**
 * A verifier over a key set, whatever the key set's source.
 *
 * **The key source is a parameter, not a URL.** `createRemoteJWKSet` and
 * `createLocalJWKSet` return the same `JWTVerifyGetKey`, so the tests exercise
 * this function itself against a real Ed25519 key pair — real signature check,
 * real expiry check — with only the HTTP fetch absent. A verifier that took a
 * URL could only be tested against a fake of itself.
 *
 * `jwtVerify` checks the signature, `exp`, `nbf` and the issuer. Two things it
 * cannot check are checked here: that the algorithm is the one Neon signs with,
 * and that the token names somebody.
 */
export function createSessionVerifier(keys: JWTVerifyGetKey, issuer: string): SessionVerifier {
  return async (header) => {
    const credential = readCredential(header);
    if (credential.kind === "absent") {
      return { kind: "absent" };
    }
    if (credential.kind === "malformed") {
      return { kind: "refused", why: credential.why };
    }

    try {
      const { payload } = await jwtVerify(credential.token, keys, {
        issuer,
        // **Pinned, not negotiated.** Left open, a token is verified with
        // whatever its own header asks for, and the header is written by
        // whoever sent it. Neon Auth signs with EdDSA and nothing else needs to
        // be accepted.
        algorithms: ["EdDSA"],
      });
      if (typeof payload.sub !== "string" || payload.sub.length === 0) {
        return {
          kind: "refused",
          why: "The token verified but carries no sub, so it names no account.",
        };
      }
      return { kind: "session", userId: payload.sub };
    } catch (error) {
      // **The library's sentence, never the token.** These reasons are logged
      // and returned to the caller; a token in one of them is a live credential
      // written to a log file. jose's messages describe the failure and quote
      // no input.
      return { kind: "refused", why: reasonFrom(error) };
    }
  };
}

function reasonFrom(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  return message.length > 0 ? message : "The token did not verify.";
}

/**
 * The production key source: Neon's JWKS endpoint.
 *
 * **One fetch per key rotation, not one per request.** `createRemoteJWKSet`
 * caches what it fetches and re-fetches only when a token names a key it has
 * not seen, which is why verifying locally beats asking the provider about
 * every request.
 *
 * The URL is ours and is passed in — `jose` hardcodes no host anywhere in its
 * shipped code, verified in the DEP-1 audit recorded in
 * `test/dependency-allowlist.test.ts`.
 */
export function remoteKeySet(jwksUrl: string): JWTVerifyGetKey {
  return createRemoteJWKSet(new URL(jwksUrl));
}
