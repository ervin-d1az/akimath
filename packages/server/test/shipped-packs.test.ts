import { parsePack } from "@akimath/contract";
import { describe, expect, it } from "vitest";

import { readShippedPacks } from "../src/adapters/shipped-packs.js";

describe("the packs this build can issue", () => {
  const packs = readShippedPacks();

  it("reads at least one, and says how much it read", () => {
    // PROC-10: an empty map would make everything below vacuous, and it is
    // reachable — a rename in `@akimath/core`'s `exports` would produce one.
    expect(packs.size).toBeGreaterThan(0);
    const items = [...packs.values()].map((p) => p.pack.items.length);
    console.log(
      `  shipped packs · ${packs.size} pack(s), ${items.join("/")} items`,
    );
  });

  it("the starter pack is the content the app already ships", () => {
    const starter = packs.get("starter");

    expect(starter).toBeDefined();
    expect(starter!.pack.items).toHaveLength(80);
    expect(starter!.pack.puzzles.length).toBeGreaterThan(0);
  });

  it("and every one validates as a pack, which is checked at startup", () => {
    // The same `parsePack` the client runs. A build shipping a pack the app
    // would refuse fails when it starts rather than in front of a player —
    // asserted here as well, so the claim is not only a comment.
    for (const [id, shipped] of packs) {
      const checked = parsePack(shipped.pack);
      expect(checked.ok, id).toBe(true);
    }
  });

  it("every item carries a digest and a skill, which is all issuing needs", () => {
    // An authored item cannot be rederived, so the digest *is* the identity —
    // and `attempts.skill_id` is NOT NULL with no template to ask.
    for (const [id, shipped] of packs) {
      for (const [index, item] of shipped.pack.items.entries()) {
        expect(item.answer.digest, `${id}[${index}]`).toMatch(/^[0-9a-f]{64}$/u);
        expect(item.skill_id, `${id}[${index}]`).toBeGreaterThanOrEqual(1);
      }
    }
  });

  it("and reading twice gives the same pack", () => {
    // It is read from disk, so this is the only thing standing between "one
    // artifact" and "whatever was on disk when that request arrived".
    expect(JSON.stringify([...readShippedPacks()])).toBe(JSON.stringify([...packs]));
  });
});
