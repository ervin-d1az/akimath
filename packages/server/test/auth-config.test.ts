import { describe, expect, it } from "vitest";

import { readAuthConfig } from "../src/auth-config.js";

const BASE = "https://ep-example-123456.us-east-1.aws.neon.tech/neondb/auth";

describe("where the keys are, and who is allowed to have signed", () => {
  it("derives both from the one URL Neon gives you", () => {
    // Neon injects `NEON_AUTH_BASE_URL`; everything else follows from it, so a
    // deployment sets one variable rather than three that can disagree.
    expect(readAuthConfig({ NEON_AUTH_BASE_URL: BASE })).toEqual({
      issuer: "https://ep-example-123456.us-east-1.aws.neon.tech",
      jwksUrl: `${BASE}/.well-known/jwks.json`,
    });
  });

  it("the issuer is the origin, not the base URL", () => {
    // Read off Neon's own troubleshooting note: "if your Neon Auth URL is
    // https://ep-xx.aws.neon.tech/neondb/auth, the issuer should be
    // https://ep-xx.aws.neon.tech". Getting this wrong rejects every valid
    // token, with an error that blames the token.
    const config = readAuthConfig({ NEON_AUTH_BASE_URL: BASE });
    expect("issuer" in config && config.issuer).not.toContain("/neondb");
  });

  it("a trailing slash on the base URL does not double up", () => {
    expect(readAuthConfig({ NEON_AUTH_BASE_URL: `${BASE}/` })).toEqual({
      issuer: "https://ep-example-123456.us-east-1.aws.neon.tech",
      jwksUrl: `${BASE}/.well-known/jwks.json`,
    });
  });

  it("an explicit JWKS URL wins, because Neon injects one at runtime", () => {
    // `NEON_AUTH_JWKS_URL` is handed to Neon Functions directly. Deriving over
    // the top of it would ignore the authoritative value in favour of a guess.
    expect(
      readAuthConfig({
        NEON_AUTH_BASE_URL: BASE,
        NEON_AUTH_JWKS_URL: "https://elsewhere.example/keys.json",
      }),
    ).toEqual({
      issuer: "https://ep-example-123456.us-east-1.aws.neon.tech",
      jwksUrl: "https://elsewhere.example/keys.json",
    });
  });

  it("no base URL is a problem, named", () => {
    // **Not a default and not a silent pass.** A server that starts without
    // knowing where the keys are refuses every request, and the operator reads
    // that as "authentication is broken" rather than "I forgot a variable".
    // The wording is asserted, not merely the presence of a problem: the
    // "unparseable" branch below also names the variable, so "it mentions
    // NEON_AUTH_BASE_URL" cannot tell the two apart.
    for (const blank of [undefined, "", "   ", "\t"]) {
      const config = readAuthConfig(blank === undefined ? {} : { NEON_AUTH_BASE_URL: blank });
      expect("problem" in config && config.problem, JSON.stringify(blank)).toContain(
        "is not set",
      );
    }
  });

  it("an unparseable base URL is a problem too, and says which value", () => {
    const config = readAuthConfig({ NEON_AUTH_BASE_URL: "not a url" });
    expect("problem" in config && config.problem).toContain("not a url");
  });

  it("http is refused, because a bearer token over plaintext is not a secret", () => {
    // The one value judgement here, and it is worth making at startup rather
    // than discovering in a packet capture. `localhost` is exempt: there is no
    // network to sniff and it is where this gets developed.
    const config = readAuthConfig({ NEON_AUTH_BASE_URL: "http://neon.example/auth" });
    expect("problem" in config && config.problem).toContain("https");
  });

  it("but http on loopback is allowed, because that is where you develop", () => {
    // All three spellings, because a developer who writes 127.0.0.1 and gets
    // told to use https would reasonably conclude the check is broken.
    for (const host of ["localhost:3000", "127.0.0.1:3000", "[::1]:3000"]) {
      const config = readAuthConfig({ NEON_AUTH_BASE_URL: `http://${host}/auth` });
      expect(config, host).toEqual({
        issuer: `http://${host}`,
        jwksUrl: `http://${host}/auth/.well-known/jwks.json`,
      });
    }
  });

  it("surrounding whitespace on either variable is not part of it", () => {
    // Environment variables arrive from shells, .env files and CI panes, and
    // every one of those has produced a trailing space at some point.
    expect(
      readAuthConfig({
        NEON_AUTH_BASE_URL: `  ${BASE}  `,
        NEON_AUTH_JWKS_URL: "   ",
      }),
    ).toEqual({
      issuer: "https://ep-example-123456.us-east-1.aws.neon.tech",
      jwksUrl: `${BASE}/.well-known/jwks.json`,
    });
  });

  it("more than one trailing slash is still no trailing slash", () => {
    expect(readAuthConfig({ NEON_AUTH_BASE_URL: `${BASE}//` })).toEqual({
      issuer: "https://ep-example-123456.us-east-1.aws.neon.tech",
      jwksUrl: `${BASE}/.well-known/jwks.json`,
    });
  });
});
