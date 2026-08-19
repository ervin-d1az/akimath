import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import { buildOpenApiDocument, OPENAPI_VERSION } from "../src/openapi/document.js";
import { CONTRACT_ROOT } from "./fixture-files.js";

/**
 * What the emitted specification must and must not contain.
 *
 * Two of these enforce invariants from `ARCHITECTURE.md` §4 against the
 * **document** rather than against code, because they are properties of the
 * wire — *the prompt travels rendered, the answer never travels online* — and
 * the wire description is the only place they can be checked before an endpoint
 * exists.
 */
/**
 * **Located by walking up, never by counting `..` segments.**
 * `fixture-files.ts` says why and this file learned it the hard way: a fixed
 * relative path lands nowhere inside Stryker's sandbox copy of the package, so
 * this whole file silently did not run under mutation testing — and every
 * mutant in `document.ts` survived, all 104 of them, because the test that
 * would have killed them was never executed.
 */
const committed = JSON.parse(
  readFileSync(join(CONTRACT_ROOT, "openapi.json"), "utf8"),
) as Record<string, unknown>;

/** Every node in the document, with the path that reaches it. */
function walk(node: unknown, path = ""): Array<{ path: string; node: unknown }> {
  const here = [{ path, node }];
  if (Array.isArray(node)) {
    return here.concat(node.flatMap((item, i) => walk(item, `${path}[${i}]`)));
  }
  if (typeof node === "object" && node !== null) {
    return here.concat(
      Object.entries(node).flatMap(([key, value]) =>
        walk(value, path === "" ? key : `${path}.${key}`),
      ),
    );
  }
  return here;
}

const NODES = walk(committed);
const KEYS = NODES.flatMap(({ path, node }) =>
  typeof node === "object" && node !== null && !Array.isArray(node)
    ? Object.keys(node).map((key) => ({ path, key }))
    : [],
);

describe("the committed document is what the code produces", () => {
  it("matches a fresh emission exactly", () => {
    expect(committed).toEqual(JSON.parse(JSON.stringify(buildOpenApiDocument())));
  });

  it("walked a real document", () => {
    // PROC-10. Every sweep below is vacuous over an empty walk, and an empty
    // walk is what a renamed file or a broken reader produces.
    expect(NODES.length).toBeGreaterThan(100);
    // eslint-disable-next-line no-console
    console.log(`  openapi · ${NODES.length} nodes, ${KEYS.length} keys`);
  });

  it("needs no server, no database and no environment to build", () => {
    // `ARCHITECTURE.md` §2's whole reason for this living in `packages/contract`.
    // Building it twice in-process is only meaningful because nothing ambient is
    // read; if it opened a socket this would be flaky rather than green.
    expect(buildOpenApiDocument()).toEqual(buildOpenApiDocument());
  });
});

describe("it is OpenAPI 3.0.3, not a later dialect wearing the number", () => {
  it("declares the version", () => {
    expect(committed["openapi"]).toBe(OPENAPI_VERSION);
    expect(OPENAPI_VERSION).toBe("3.0.3");
  });

  it("carries none of the later spellings anywhere", () => {
    // Each of these is 2020-12's or draft-7's way of saying something 3.0.3 says
    // differently. Asserted over the whole document, because a schema is not the
    // only place one can appear.
    const forbidden = ["$schema", "const", "propertyNames", "prefixItems", "$defs", "unevaluatedProperties"];
    const found = KEYS.filter((k) => forbidden.includes(k.key));
    expect(found.map((k) => `${k.path}.${k.key}`)).toEqual([]);
  });

  it("expresses an exclusive bound as a boolean, never as a number", () => {
    for (const { path, node } of NODES) {
      if (typeof node !== "object" || node === null || Array.isArray(node)) continue;
      for (const key of ["exclusiveMinimum", "exclusiveMaximum"]) {
        if (key in node) {
          expect(typeof (node as Record<string, unknown>)[key], `${path}.${key}`).toBe(
            "boolean",
          );
        }
      }
    }
  });

  it("never expresses a type as an array", () => {
    for (const { path, node } of NODES) {
      if (typeof node === "object" && node !== null && "type" in node) {
        expect(Array.isArray((node as Record<string, unknown>)["type"]), path).toBe(false);
      }
    }
  });
});

describe("no response is polymorphic", () => {
  it("contains no oneOf, anyOf, allOf or discriminator", () => {
    // `ARCHITECTURE.md` §2, and the frozen pack format already obeys the same
    // rule: variance lives inside an opaque payload, not in a union the client
    // has to discriminate.
    const found = KEYS.filter((k) =>
      ["oneOf", "anyOf", "allOf", "discriminator"].includes(k.key),
    );
    expect(found.map((k) => `${k.path}.${k.key}`)).toEqual([]);
  });

  it("and the variance that does exist is an opaque object", () => {
    // The control: "no unions" is also true of a document with no varying
    // shapes at all, which would mean the rule had not been exercised.
    const schemas = (committed["components"] as { schemas: Record<string, Record<string, unknown>> })
      .schemas;
    const verdict = schemas["Verdict"] as { properties: Record<string, unknown> };
    expect(verdict.properties["payload"]).toEqual({
      type: "object",
      additionalProperties: {},
    });
  });
});

describe("the answer never travels and the prompt travels rendered", () => {
  it("no property anywhere names a template, a version or a seed", () => {
    // `ARCHITECTURE.md` §4: the server emits and records those three, and they
    // "never appear in the response" — they reconstruct the problem.
    const rederivationKey = /^(template_?id|template_?version|seed)$/i;
    const offenders = NODES.flatMap(({ path, node }) =>
      path.endsWith("properties") && typeof node === "object" && node !== null
        ? Object.keys(node)
            .filter((name) => rederivationKey.test(name))
            .map((name) => `${path}.${name}`)
        : [],
    );
    expect(offenders).toEqual([]);
  });

  it("the item response is the item id, the prompt and the keypad — and nothing else", () => {
    // `ARCHITECTURE.md`:202 still lists `options`, contradicting §4's own
    // resolution. A field offering a child a set of answers to choose from is a
    // different product; that line is corrected by this change.
    const schemas = (committed["components"] as { schemas: Record<string, Record<string, unknown>> })
      .schemas;
    const item = schemas["ItemResponse"] as {
      properties: Record<string, unknown>;
      required: string[];
    };
    expect(Object.keys(item.properties).sort()).toEqual(["itemId", "keypad", "prompt"]);
    expect(item.required.sort()).toEqual(["itemId", "keypad", "prompt"]);
  });

  it("a submission asserts no verdict of its own", () => {
    // §4: the sync endpoint "does not accept an `ok` field — that is what makes
    // the invariant true by construction rather than by discipline". A schema is
    // where by-construction lives.
    const schemas = (committed["components"] as { schemas: Record<string, Record<string, unknown>> })
      .schemas;
    const submission = schemas["AttemptSubmission"] as { properties: Record<string, unknown> };
    for (const claim of ["ok", "correct", "isCorrect", "verdict", "score"]) {
      expect(Object.keys(submission.properties)).not.toContain(claim);
    }
  });

  it("the sweep would catch one", () => {
    // The control for both sweeps above: over a document that does contain the
    // forbidden names, the same predicates must fire. Without this they pass for
    // a regex that matches nothing.
    const planted = walk({
      components: { schemas: { X: { properties: { templateId: {}, seed: {} } } } },
    });
    const rederivationKey = /^(template_?id|template_?version|seed)$/i;
    const offenders = planted.flatMap(({ path, node }) =>
      path.endsWith("properties") && typeof node === "object" && node !== null
        ? Object.keys(node).filter((n) => rederivationKey.test(n))
        : [],
    );
    expect(offenders.sort()).toEqual(["seed", "templateId"]);
  });
});

describe("every endpoint the documents name is described", () => {
  it("covers the three the client spike measured and the five §5 names", () => {
    const paths = Object.keys((committed["paths"] as Record<string, unknown>)).sort();
    expect(paths).toEqual(
      [
        "/attempts",
        "/items/next",
        "/me",
        "/me/history",
        "/me/standing",
        "/packs/{packId}",
        "/players/link",
      ].sort(),
    );
  });

  it("every operation declares every error the server can return", () => {
    // The router answers 400, 401, 404 and 405, and a status it can emit that
    // the contract does not describe is exactly the drift this document exists
    // to prevent. 405 belongs to a *path* rather than an operation — a request
    // that matched the path and no operation on it — so the conventional
    // spelling declares it on all of them.
    const operations = NODES.filter(
      ({ node }) => typeof node === "object" && node !== null && "responses" in node,
    );
    expect(operations.length).toBeGreaterThan(0);

    for (const { path, node } of operations) {
      const responses = (node as { responses: Record<string, unknown> }).responses;
      for (const status of ["400", "401", "404", "405"]) {
        expect(Object.keys(responses), `\${path} is missing \${status}`).toContain(status);
      }
    }
  });

  it("every error response is the frozen Error shape", () => {
    // Not merely present: a 405 declared with no body, or with some other
    // schema, would let the router answer off-contract while this file said it
    // could not.
    for (const { node } of NODES) {
      if (typeof node !== "object" || node === null || !("responses" in node)) {
        continue;
      }
      const responses = (node as { responses: Record<string, unknown> }).responses;
      for (const [status, response] of Object.entries(responses)) {
        if (!status.startsWith("4") && !status.startsWith("5")) {
          continue;
        }
        expect(JSON.stringify(response)).toContain(
          '"$ref":"#/components/schemas/Error"',
        );
      }
    }
  });

  it("every operation has an operationId, and they are unique", () => {
    // ADR 0001 records that the rejected generator discarded these in favour of
    // path-derived names. The hand-written client uses them, so they have to be
    // there and they have to be distinct.
    const ids = NODES.flatMap(({ node }) =>
      typeof node === "object" && node !== null && "operationId" in node
        ? [(node as { operationId: string }).operationId]
        : [],
    );
    expect(ids.length).toBeGreaterThan(0);
    expect(new Set(ids).size).toBe(ids.length);
  });
});

describe("a player's band is one set, declared once", () => {
  /** Every `enum` in the document that spells a band, with where it was found. */
  const bandEnums = NODES.flatMap(({ path, node }) =>
    typeof node === "object" &&
    node !== null &&
    Array.isArray((node as { enum?: unknown }).enum) &&
    (node as { enum: unknown[] }).enum.includes("under_13")
      ? [{ path, values: (node as { enum: string[] }).enum }]
      : [],
  );

  it("the link request declares one, and so does the profile", () => {
    // Found by sweeping rather than by naming the two schemas: a third place
    // that grows a band set is exactly the drift this checks for, and a test
    // naming today's two cannot see it.
    expect(bandEnums.map(({ path }) => path).sort()).toEqual([
      "components.schemas.Me.properties.ageBand",
      "components.schemas.PlayerLink.properties.ageBand",
    ]);
  });

  it("and they are the same set, in the same order", () => {
    // Order too, not just membership: the document is byte-diffed, so a set
    // that agrees but reorders is a diff somebody has to read and dismiss.
    const distinct = new Set(bandEnums.map(({ values }) => JSON.stringify(values)));
    expect(distinct.size).toBe(1);
    expect([...distinct][0]).toBe(JSON.stringify(["under_13", "13_17", "adult"]));
  });
});
