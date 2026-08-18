import {
  answerDigest,
  parsePack,
  renderCanonicalAnswer,
  type DiagnosisCopy,
  type Item,
  type Pack,
} from "@akimath/contract";

import { rederive, type TemplateRegistry } from "../registry.js";
import type { Declaration } from "./declaration.js";
import { liftAuthored, readAuthoredFile } from "./lift.js";
import { seedAt } from "./seeds.js";

/**
 * A declaration and a registry in, a pack out.
 *
 * **PURE** — reading the authored files is injected, so the whole assembly is
 * testable without a filesystem and the CLI beside it decides nothing.
 *
 * **A pack is assembled from sources**, in the order they are declared, and a
 * source is either a template invocation or an authored file. That is the shape
 * that lets this exist at all: `packages/core` ships one template and the app
 * draws six families, so a wholly generated pack would take a player from six
 * kinds of question to one. Sources make the five authored families
 * first-class rather than a migration step, and turn "add a template" into an
 * edit to a declaration.
 */

export interface BuildInputs {
  readonly registry: TemplateRegistry;
  /** Resolves a source's declared path to its contents. */
  readonly readAuthored: (path: string) => string;
  /**
   * The copy shown when a wrong answer matches no distractor, per skill.
   *
   * Required rather than defaulted: the frozen validator refuses an item whose
   * skill has no fallback, and inventing a placeholder here would ship "TODO"
   * to a player. A skill with nothing to say fails the build instead.
   */
  readonly fallbacks: ReadonlyMap<number, DiagnosisCopy>;
}

/** What was built, beside the pack — so a build can report rather than assert. */
export interface BuildReport {
  readonly generated: number;
  readonly authored: number;
  readonly diagnosed: number;
  readonly byFamily: ReadonlyMap<string, number>;
}

export interface BuildResult {
  readonly pack: Pack;
  readonly report: BuildReport;
}

/** One generated item, in the frozen envelope. */
function fromTemplate(
  declaration: Declaration,
  registry: TemplateRegistry,
  source: Extract<Declaration["sources"][number], { kind: "template" }>,
  seedIndex: number,
): Item {
  const generated = rederive(registry, {
    templateId: source.templateId,
    templateVersion: source.templateVersion,
    seed: seedAt(declaration.seedBase, seedIndex),
    ladderStep: source.ladderStep,
  });

  // The template carries an exact `Rational` and never a string, because
  // rendering belongs to the contract — which already owns what `5/4` looks
  // like and is checked against Dart on the same fixture.
  const canonical = renderCanonicalAnswer(
    generated.answer.numerator,
    generated.answer.denominator,
  );

  return {
    skill_id: source.skillId,
    ladder_step: generated.ladderStep,
    keypad: "item",
    stimulus: {
      kind: "arithmetic",
      payload: {
        operator: generated.operator,
        left: generated.left,
        right: generated.right,
      },
    } as Item["stimulus"],
    answer: {
      shape: generated.answer.denominator === 1n ? "integer" : "fraction",
      digest: answerDigest(declaration.packSalt, canonical),
    },
    diagnosis: null,
  };
}

export function buildPack(
  declaration: Declaration,
  inputs: BuildInputs,
): BuildResult {
  const items: Item[] = [];
  let generated = 0;
  let authored = 0;

  for (const source of declaration.sources) {
    if (source.kind === "template") {
      for (let n = 0; n < source.count; n += 1) {
        // The counter spans the whole build, not each source, so two template
        // sources never issue the same seed.
        items.push(fromTemplate(declaration, inputs.registry, source, generated));
        generated += 1;
      }
      continue;
    }
    for (const raw of readAuthoredFile(inputs.readAuthored(source.path))) {
      items.push(
        liftAuthored(raw, { skillId: source.skillId, packSalt: declaration.packSalt }),
      );
      authored += 1;
    }
  }

  const skillIds = [...new Set(items.map((item) => item.skill_id))].sort((a, b) => a - b);
  for (const skillId of skillIds) {
    if (!inputs.fallbacks.has(skillId)) {
      throw new TypeError(
        `skill ${skillId} has items but no fallback copy; a wrong answer there ` +
          `would be met with silence`,
      );
    }
  }

  const pack: Pack = {
    pack_format_version: 1,
    pack_salt: declaration.packSalt,
    issued_at: declaration.issuedAt,
    expires_at: declaration.expiresAt,
    // Every skill an item names is declared available. The lattice that decides
    // what is locked is the skill map's, at F5; a pack that declared everything
    // locked would be a pack with nothing to play.
    skill_nodes: skillIds.map((skill_id) => ({ skill_id, state: "available" as const })),
    skill_fallbacks: skillIds.map((skill_id) => ({
      skill_id,
      diagnosis: inputs.fallbacks.get(skill_id) as DiagnosisCopy,
    })),
    items,
    puzzles: [],
  };

  // **Validated here, before anything is written.** The CLI cannot be the only
  // place this happens: a caller that assembled a pack and skipped the check
  // would produce something no reader accepts, and the failure would surface on
  // a device rather than in a build.
  const verdict = parsePack(pack);
  if (!verdict.ok) {
    throw new TypeError(`the assembled pack is not valid: ${verdict.tag}`);
  }

  const byFamily = new Map<string, number>();
  for (const item of items) {
    const kind = item.stimulus.kind;
    byFamily.set(kind, (byFamily.get(kind) ?? 0) + 1);
  }

  return {
    pack: verdict.pack,
    report: {
      generated,
      authored,
      diagnosed: items.filter((item) => item.diagnosis !== null).length,
      byFamily,
    },
  };
}
