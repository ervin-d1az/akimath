import { describe, expect, it } from "vitest";

import { parsePack, type Pack } from "../src/pack.js";
import { declaredState, SKILL_NODE_STATES } from "../src/skill-map.js";

const DIGEST = "abcdef0123456789".repeat(4);

const FALLBACK = {
  misconception: "unclassified",
  steps: ["Vuelve a ver el paso de en medio."],
  explain: "Aquí va el razonamiento completo, paso por paso.",
};

function packDeclaring(state: string): Record<string, unknown> {
  return {
    pack_format_version: 1,
    pack_salt: "a1b2c3d4e5f60718293a4b5c6d7e8f90",
    issued_at: "2026-08-16T00:00:00.000Z",
    expires_at: "2026-09-15T00:00:00.000Z",
    skill_nodes: [{ skill_id: 4, state }],
    skill_fallbacks: [{ skill_id: 4, diagnosis: FALLBACK }],
    items: [
      {
        skill_id: 4,
        ladder_step: 1,
        keypad: "item",
        stimulus: { kind: "numberSeries", payload: { terms: [2, 4, 8], unknown_index: 2 } },
        answer: { shape: "integer", digest: DIGEST },
        diagnosis: null,
      },
    ],
    puzzles: [],
  };
}

describe("skill-map node state", () => {
  it("closes at the four states the documents name", () => {
    expect(SKILL_NODE_STATES).toEqual(["locked", "available", "started", "mastered"]);
  });

  it("yields whatever state the pack declared, for every state", () => {
    for (const state of SKILL_NODE_STATES) {
      const parsed = parsePack(packDeclaring(state));
      expect(parsed.ok).toBe(true);
      if (!parsed.ok) {
        continue;
      }
      const pack: Pack = parsed.pack;
      expect(declaredState(pack.skill_nodes, 4)).toBe(state);
    }
  });

  it("reads the state rather than computing it from the item count", () => {
    const twoItems = packDeclaring("locked") as { items: unknown[] };
    twoItems.items = [twoItems.items[0], twoItems.items[0]];
    const parsed = parsePack(twoItems);
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    expect(declaredState(parsed.pack.skill_nodes, 4)).toBe("locked");
  });

  it("rejects a referenced node the pack declared no state for", () => {
    const undeclared = { ...packDeclaring("started"), skill_nodes: [] };
    expect(parsePack(undeclared)).toEqual({ ok: false, tag: "undeclared_skill_node" });
  });

  it("reports no state for a node nobody declared", () => {
    expect(declaredState([{ skill_id: 4, state: "started" }], 9)).toBeNull();
  });
});
