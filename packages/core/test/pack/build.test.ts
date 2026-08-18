import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import type { DiagnosisCopy } from "@akimath/contract";
import { describe, expect, it } from "vitest";

import { CORE_REGISTRY } from "../../src/golden.js";
import { registryOf } from "../../src/registry.js";
import type { Template } from "../../src/template.js";
import { buildPack } from "../../src/pack/build.js";
import { parseDeclaration } from "../../src/pack/declaration.js";
import { parseMisconceptions } from "../../src/pack/misconceptions.js";

const AUTHORED_PATH = "../../app/assets/packs/starter.json";
const AUTHORED = readFileSync(
  fileURLToPath(new URL("../../../../app/assets/packs/starter.json", import.meta.url)),
  "utf8",
);

const FALLBACK: DiagnosisCopy = {
  misconception: "sin_diagnostico",
  steps: ["Vuelve a leer el reto.", "Comprueba tu resultado."],
  explain: "Aquí va el razonamiento completo, paso por paso, sin regaños.",
};

const MISCONCEPTIONS = parseMisconceptions(
  JSON.parse(
    readFileSync(fileURLToPath(new URL("../../content/misconceptions.json", import.meta.url)), "utf8"),
  ),
);

const inputs = (fallbacks: ReadonlyMap<number, DiagnosisCopy> = new Map([[1, FALLBACK]])) => ({
  misconceptions: MISCONCEPTIONS,
  registry: CORE_REGISTRY,
  readAuthored: (path: string) => {
    if (path !== AUTHORED_PATH) throw new Error(`unexpected path ${path}`);
    return AUTHORED;
  },
  fallbacks,
});

const declaration = (over: Record<string, unknown> = {}) =>
  parseDeclaration({
    pack_salt: "a1b2c3d4e5f60718293a4b5c6d7e8f90",
    seed_base: "1000",
    issued_at: "2026-08-18T00:00:00.000Z",
    expires_at: "2026-11-18T00:00:00.000Z",
    sources: [
      { kind: "template", template_id: "arith.integer.subtract", template_version: 2, ladder_step: 3, count: 5, skill_id: 1 },
      { kind: "authored", path: AUTHORED_PATH, skill_id: 1 },
    ],
    ...over,
  });

describe("a pack is assembled from sources", () => {
  it("carries every item from both kinds of source", () => {
    const { pack, report } = buildPack(declaration(), inputs());

    expect(report.generated).toBe(5);
    expect(report.authored).toBe(70);
    expect(pack.items).toHaveLength(75);
  });

  it("keeps the declared order, so the pack's order stays a product decision", () => {
    const { pack } = buildPack(declaration(), inputs());
    // Five generated first, because the declaration says so.
    expect(pack.items.slice(0, 5).every((i) => i.stimulus.kind === "arithmetic")).toBe(true);
  });

  it("still offers all six families, which is the point of sources", () => {
    // The assertion that this change cannot regress what a player sees. One
    // template exists; five families are authored; a wholly generated pack
    // would offer one kind of question.
    const { report } = buildPack(declaration(), inputs());

    // eslint-disable-next-line no-console
    console.log(
      `  pack build · ${report.generated} generated + ${report.authored} authored → ` +
        [...report.byFamily.entries()].sort().map(([k, n]) => `${k} ${n}`).join(", "),
    );
    expect(report.byFamily.size).toBe(6);
  });

  it("refuses to return a pack the frozen validator rejects", () => {
    // **PROC-11.** This asserted `not.toThrow()` first, which is a tautology:
    // deleting the validation entirely left it green. It has to feed something
    // invalid and watch the build refuse it.
    //
    // The item lifts cleanly — the lift is an envelope concern and does not
    // read inside a payload — and is then caught by `parseStimulus` as
    // `unknown_index_out_of_range`.
    const broken = JSON.stringify({
      items: [
        {
          id: "hole-off-the-end",
          ladder_step: 1,
          answer: "8",
          stimulus: { kind: "numberSeries", payload: { terms: [2, 4, 6], unknown_index: 99 } },
        },
      ],
    });

    expect(() =>
      buildPack(declaration({ sources: [{ kind: "authored", path: "broken.json", skill_id: 1 }] }), {
        ...inputs(),
        readAuthored: () => broken,
      }),
    ).toThrow(/unknown_index_out_of_range/);
  });
});

describe("a generated answer is shaped by what the template produced", () => {
  it("calls a fractional answer a fraction", () => {
    // The one shipped template returns integers, so the fraction branch is
    // unreachable through it — hardcoding "integer" passed the whole suite.
    // A registry of one synthetic template is what exercises the other side.
    const fractional: Template = {
      id: "spike.fraction",
      version: 1,
      generate: (ref) => ({
        prompt: [],
        answer: { numerator: 5n, denominator: 4n },
        ladderStep: ref.ladderStep,
        operator: "+",
        left: { num: 1, den: 2 },
        right: { num: 3, den: 4 },
      }),
    };

    const { pack } = buildPack(
      declaration({
        sources: [{ kind: "template", template_id: "spike.fraction", template_version: 1, ladder_step: 2, count: 1, skill_id: 1 }],
      }),
      { ...inputs(), registry: registryOf([fractional]) },
    );

    expect(pack.items[0]?.answer.shape).toBe("fraction");
  });

  it("calls a whole answer an integer", () => {
    const { pack } = buildPack(declaration({
      sources: [{ kind: "template", template_id: "arith.integer.subtract", template_version: 2, ladder_step: 3, count: 1, skill_id: 1 }],
    }), inputs());
    expect(pack.items[0]?.answer.shape).toBe("integer");
  });
});

describe("the same declaration always produces the same pack", () => {
  it("two builds are byte-identical", () => {
    const a = JSON.stringify(buildPack(declaration(), inputs()).pack);
    const b = JSON.stringify(buildPack(declaration(), inputs()).pack);
    expect(a).toBe(b);
  });

  it("a different seed base produces different items", () => {
    // req-builder-deterministic. A base that is accepted and ignored would
    // satisfy the byte-identity check above perfectly.
    const a = buildPack(declaration(), inputs()).pack.items.slice(0, 5);
    const b = buildPack(declaration({ seed_base: "999999" }), inputs()).pack.items.slice(0, 5);
    expect(JSON.stringify(a)).not.toBe(JSON.stringify(b));
  });

  it("two template sources never share a seed", () => {
    // The counter spans the build, not each source. Per-source counters would
    // issue the same item twice and the pack would look fine.
    const { pack } = buildPack(
      declaration({
        sources: [
          { kind: "template", template_id: "arith.integer.subtract", template_version: 2, ladder_step: 3, count: 3, skill_id: 1 },
          { kind: "template", template_id: "arith.integer.subtract", template_version: 2, ladder_step: 3, count: 3, skill_id: 1 },
        ],
      }),
      inputs(),
    );
    const rendered = pack.items.map((i) => JSON.stringify(i.stimulus));
    expect(new Set(rendered).size).toBe(6);
  });
});

describe("no answer travels in the clear", () => {
  it("no item's canonical answer appears anywhere in the pack", () => {
    const { pack } = buildPack(declaration(), inputs());
    const serialised = JSON.stringify(pack);

    // The authored answers are the ones we can name from outside, so they are
    // the ones swept for. Reported, so a sweep that checks nothing cannot pass.
    const answers = (JSON.parse(AUTHORED) as { items: { answer: string }[] }).items.map(
      (i) => i.answer,
    );
    const leaked = answers.filter((a) => serialised.includes(`"${a}"`));

    expect(leaked).toEqual([]);
    expect(answers.length).toBe(70);
  });
});

describe("every skill can answer for itself", () => {
  it("emits a node and a fallback for each skill an item names", () => {
    const { pack } = buildPack(declaration(), inputs());
    expect(pack.skill_nodes.map((n) => n.skill_id)).toEqual([1]);
    expect(pack.skill_fallbacks.map((f) => f.skill_id)).toEqual([1]);
  });

  it("refuses a skill that has items but no fallback copy", () => {
    // The frozen validator refuses this too, but it refuses it as
    // `missing_skill_fallback` after assembly. Failing here names the skill.
    expect(() => buildPack(declaration(), inputs(new Map()))).toThrow(/skill 1/);
  });

  it("declares a node for every distinct skill, not just the first", () => {
    const { pack } = buildPack(
      declaration({
        sources: [
          { kind: "authored", path: AUTHORED_PATH, skill_id: 1 },
          { kind: "template", template_id: "arith.integer.subtract", template_version: 2, ladder_step: 3, count: 2, skill_id: 4 },
        ],
      }),
      inputs(new Map([[1, FALLBACK], [4, FALLBACK]])),
    );
    expect(pack.skill_nodes.map((n) => n.skill_id)).toEqual([1, 4]);
  });
});
