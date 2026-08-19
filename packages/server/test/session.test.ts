import { describe, expect, it } from "vitest";

import { readCredential } from "../src/session.js";

/**
 * Reading the `Authorization` header, and nothing else.
 *
 * No key, no clock, no network: this half decides whether the caller even
 * *offered* a credential, which is a different question from whether the
 * credential is good, and it is the half that can be wrong in silence. A parser
 * that accepts `Bearer` with no token hands an empty string to the verifier and
 * gets a confusing error from a library instead of a clear refusal from us.
 */
describe("what the caller offered", () => {
  it("no header at all is not a malformed one", () => {
    // The distinction is the whole point: absent earns "you need a session",
    // malformed earns "that is not one", and collapsing them makes the second
    // unanswerable for whoever is holding a broken client.
    expect(readCredential(undefined)).toEqual({ kind: "absent" });
    expect(readCredential("")).toEqual({ kind: "absent" });
    expect(readCredential("   ")).toEqual({ kind: "absent" });
  });

  it("a bearer token is read out of it", () => {
    expect(readCredential("Bearer abc.def.ghi")).toEqual({
      kind: "bearer",
      token: "abc.def.ghi",
    });
  });

  it("the scheme is case-insensitive, because RFC 7235 says it is", () => {
    // A client sending `bearer` is not broken, and refusing it would be a bug
    // found in the field rather than here.
    for (const scheme of ["Bearer", "bearer", "BEARER", "BeArEr"]) {
      expect(readCredential(`${scheme} tok`)).toEqual({ kind: "bearer", token: "tok" });
    }
  });

  it("surrounding whitespace is not part of the token", () => {
    expect(readCredential("  Bearer   tok  ")).toEqual({ kind: "bearer", token: "tok" });
  });

  it("a scheme with no token names no credential", () => {
    // All three arrive here as the bare word `Bearer` — the trim happens first —
    // so the reason is about a header with nothing after the scheme, not about
    // an empty token. The wording is asserted because "it is malformed" is true
    // of every refusal and so distinguishes nothing.
    for (const header of ["Bearer", "Bearer ", "bearer    "]) {
      const credential = readCredential(header);
      expect(credential.kind === "malformed" && credential.why).toContain(
        "names no credential",
      );
    }
  });

  it("another scheme is malformed here, however valid it is elsewhere", () => {
    // Basic and friends are not wrong in general; they are wrong for this API,
    // which declares exactly one scheme in `contract/openapi.json`. The reason
    // names the scheme offered, so the client author can see what was sent.
    const basic = readCredential("Basic dXNlcjpwYXNz");
    expect(basic.kind === "malformed" && basic.why).toContain("Basic");
    const other = readCredential("token abc");
    expect(other.kind === "malformed" && other.why).toContain("token");
  });

  it("a token with a space in it is malformed rather than truncated", () => {
    // `Bearer a b` silently becoming the token `a` is the failure worth naming:
    // it turns a client bug into an authentication failure nobody can explain.
    const credential = readCredential("Bearer a b");
    expect(credential.kind === "malformed" && credential.why).toContain("space");
  });

  it("each refusal says a different thing, or it says nothing", () => {
    // Three ways to be malformed and three reasons. Asserted as a set because
    // the failure this catches is two branches collapsing onto one message,
    // which no single-case test can see.
    const reasons = ["Bearer", "Basic x", "Bearer a b"].map((header) => {
      const credential = readCredential(header);
      return credential.kind === "malformed" ? credential.why : "";
    });
    expect(new Set(reasons).size).toBe(3);
  });

  it("every refusal says why, in one line", () => {
    // A refusal with no reason is a support ticket. These strings reach a
    // developer, never a player, so they are English like the rest of the code.
    for (const header of ["Bearer", "Basic x", "Bearer a b"]) {
      const credential = readCredential(header);
      expect(credential.kind).toBe("malformed");
      if (credential.kind === "malformed") {
        expect(credential.why.length).toBeGreaterThan(0);
        expect(credential.why).not.toContain("\n");
      }
    }
  });
});
