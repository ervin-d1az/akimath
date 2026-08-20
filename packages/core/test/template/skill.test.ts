import { describe, expect, it } from "vitest";

import { coreRegistry } from "../../src/index.js";
import { issuable, resolve } from "../../src/registry.js";
import type { TemplateRef } from "../../src/template.js";

/**
 * Which skill a template exercises, and why the answer lives on the template.
 *
 * `attempts.skill_id` is `NOT NULL` and nothing on the wire carries it: an
 * attempt names an item, and the item is a `(template_id, template_version,
 * seed, ladder_step)` reference. So the server has to derive the skill, and the
 * only thing in that reference that knows is the template.
 *
 * The pack declaration used to state it a second time, next to the template
 * source. Two places stating one fact is one place that can be wrong, and the
 * wrong one would be the pack's — items filed under a skill their template does
 * not exercise, rated against the wrong `user_skills` row.
 */
describe("a template knows which skill it exercises", () => {
  // Through the package's own front door, which is how the server reaches it.
  const registry = coreRegistry();

  it("the front door hands back the shipped registry, and the same one twice", () => {
    // `coreRegistry()` is a call rather than the constant so that every export
    // stays a function (`public_surface.test.ts`). A call that built a fresh
    // registry each time would still pass that rule and would quietly make two
    // callers disagree about identity.
    expect(coreRegistry()).toBe(registry);
    expect(registry.byKey.size).toBeGreaterThan(0);
  });

  it("every shipped version declares one, and reports how many were checked", () => {
    const shipped = [...registry.byKey.values()];
    // PROC-10: a registry that emptied would make this vacuously true.
    expect(shipped.length).toBeGreaterThan(0);
    console.log(`  template skills · checked ${shipped.length} shipped version(s)`);

    for (const template of shipped) {
      expect(template.skillId, `${template.id}@${template.version}`)
        .toBeGreaterThanOrEqual(1);
      expect(Number.isInteger(template.skillId)).toBe(true);
    }
  });

  it("and a recorded reference resolves to it", () => {
    const ref: Pick<TemplateRef, "templateId" | "templateVersion"> = {
      templateId: "arith.integer.subtract",
      templateVersion: 1,
    };
    expect(resolve(registry, ref).skillId).toBe(1);
  });

  it("two versions of one template may differ, and today do not", () => {
    // A version is frozen history. Reclassifying a skill is therefore a new
    // version, never an edit — and an attempt recorded under the old one keeps
    // the skill it was rated against, because `attempts.skill_id` is stored.
    const versions = [...registry.byKey.values()]
      .filter((template) => template.id === "arith.integer.subtract");
    expect(versions).toHaveLength(2);
    expect(new Set(versions.map((template) => template.skillId))).toEqual(new Set([1]));
  });

  it("the registry that ships is the one that can still issue", () => {
    // `registry` is what the server resolves against, so it has to carry
    // retired versions too — this only asserts that nothing shipped is retired
    // yet, which is the fact that would otherwise be assumed.
    expect(issuable(registry)).toHaveLength(registry.byKey.size);
  });
});
