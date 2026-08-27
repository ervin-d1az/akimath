import { describe, expect, it } from "vitest";

import { IMPLEMENTED_OPERATIONS } from "../src/routing.js";
import { schemaNamed } from "./support/contract.js";

/**
 * Why `GET /items/next` is the last operation still answering 501.
 *
 * **The blocker is an asymmetry between two frozen schemas, and it is a fact of
 * the document rather than an opinion about it.** `AttemptSubmission` names an
 * answered item in one of two ways — `itemId` for something this server issued,
 * `packRef` for `(packId, index)` in an offline pack, mirroring
 * `attempts_one_source`. `ItemResponse` carries only the first. So an item
 * handed back by `GET /items/next` can be addressed as an issued item and in no
 * other way.
 *
 * That settles the endpoint, because the only items this server has to offer
 * are pack items. `POST /packs` issues a copy of the shipped pack — eighty
 * authored items whose manifest entries are digests — and
 * `refForIssuedItem` resolves an `itemId` against `issued_items` alone, a table
 * that records `(template_id, template_version, seed, ladder_step)` and nothing
 * else. A digest item has no template, so no `itemId` value resolves to one.
 * An item served here could therefore be shown and never answered: the loop
 * would not close, for any item, in either direction.
 *
 * **This is a gate rather than a comment because the reason is the part that
 * gets lost.** The 501 is already held to `IMPLEMENTED_OPERATIONS` by
 * `contract-parity.test.ts`; what that gate cannot say is *why* the list is
 * short. The day `ItemResponse` gains a `packRef`, the second assertion below
 * goes red and says the blocker is lifted — which is the moment the endpoint
 * becomes buildable, and the moment this file should be deleted.
 *
 * A second, independent reason is deliberately **not** asserted here.
 * `ItemResponse.prompt` is a flat token stream, and `src/stimulus/index.ts` in
 * `packages/contract` records design decision D1 rejecting exactly that shape
 * for the pack format — "a 3×3 matrix, a function machine, seven elastic tiles,
 * two pair-cards and a figurate figure are not a flat list" — so fifty of the
 * shipped pack's eighty items cannot be rendered into it at all. That is a
 * design correction owed to `ItemResponse`, which `api-schemas.ts` itself flags
 * as "transcribed from ADR 0001's spike"; a test asserting it would be
 * asserting the opinion rather than the obstacle. The addressing gap blocks on
 * its own.
 */

/** The properties a frozen schema declares, by name. */
function propertiesOf(name: string): readonly string[] {
  const schema = schemaNamed(name);
  const properties = schema["properties"];
  if (typeof properties !== "object" || properties === null) {
    throw new Error(`the frozen ${name} declares no properties`);
  }
  return Object.keys(properties).sort();
}

describe("an item response cannot address a pack item", () => {
  const submission = propertiesOf("AttemptSubmission");
  const response = propertiesOf("ItemResponse");

  it("reports what it compared", () => {
    // PROC-10: a schema name that stopped resolving would take the assertions
    // below with it, and `schemaNamed` throws rather than returning undefined —
    // but a schema that resolved to an empty object would not, so the counts
    // are reported and required to be non-zero.
    expect(submission.length).toBeGreaterThan(0);
    expect(response.length).toBeGreaterThan(0);
    console.log(
      `  item addressing · AttemptSubmission ${submission.length} properties ` +
        `(${submission.join(", ")}) → ItemResponse ${response.length} ` +
        `(${response.join(", ")})`,
    );
  });

  it("an attempt may name either an issued item or a pack item", () => {
    // The control for the assertion below: it is only an *asymmetry* if the
    // submission side really does carry both spellings.
    expect(submission).toContain("itemId");
    expect(submission).toContain("packRef");
  });

  it("an item response may name only an issued item", () => {
    expect(response).toContain("itemId");
    expect(
      response,
      "ItemResponse has gained a packRef: GET /items/next can now hand back an " +
        "item from an offline pack that POST /attempts is able to accept, so the " +
        "blocker is lifted. Build getNextItem and delete this file.",
    ).not.toContain("packRef");
  });

  it("and it cannot be widened by a server that feels like it", () => {
    // Without this, "ItemResponse has no packRef" would be a gap a handler
    // could paper over by emitting one anyway. `additionalProperties: false`
    // is what makes the absence binding on the server as well as the client.
    expect(schemaNamed("ItemResponse")["additionalProperties"]).toBe(false);
  });

  it("so getNextItem is not built", () => {
    expect(
      IMPLEMENTED_OPERATIONS,
      "getNextItem is listed as built while ItemResponse still cannot address a " +
        "pack item. Every item this server can offer comes from an offline pack, " +
        "and an item served with an itemId that resolves against issued_items " +
        "alone can be shown and never answered.",
    ).not.toContain("getNextItem");
  });
});
