import type { GeneratedItem, Template, TemplateRef } from "./template.js";

/**
 * Which generator a recorded `(templateId, templateVersion)` resolves to.
 *
 * The registry is a value, built from a list, with no ambient state — so a test
 * builds its own and nothing global has to be reset between them.
 */
export interface TemplateRegistry {
  readonly byKey: ReadonlyMap<string, Template>;
}

const keyOf = (id: string, version: number): string => `${id}@${version}`;

export function registryOf(templates: readonly Template[]): TemplateRegistry {
  const byKey = new Map<string, Template>();
  for (const template of templates) {
    const key = keyOf(template.id, template.version);
    if (byKey.has(key)) {
      throw new Error(`two templates claim ${key}`);
    }
    byKey.set(key, template);
  }
  return { byKey };
}

/**
 * The generator for a recorded reference, retired or not.
 *
 * Retirement is about issuing, not about history: an attempt from before a
 * version was retired still has to rederive, or the append-only table records
 * problems nobody can reconstruct.
 */
export function resolve(
  registry: TemplateRegistry,
  ref: Pick<TemplateRef, "templateId" | "templateVersion">,
): Template {
  const found = registry.byKey.get(keyOf(ref.templateId, ref.templateVersion));
  if (found === undefined) {
    throw new Error(
      `no template ${keyOf(ref.templateId, ref.templateVersion)}; an issued ` +
        "item can never stop being rederivable, so a version is added and " +
        "never removed",
    );
  }
  return found;
}

/** The item a recorded reference stands for. */
export function rederive(
  registry: TemplateRegistry,
  ref: TemplateRef,
): GeneratedItem {
  return resolve(registry, ref).generate(ref);
}

/** The versions still available to issue — retirement's only effect. */
export function issuable(registry: TemplateRegistry): readonly Template[] {
  return [...registry.byKey.values()].filter((t) => t.retired !== true);
}
