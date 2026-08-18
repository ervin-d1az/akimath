import { z } from "zod";

/**
 * The skill map's node states travel in the pack and are never derived
 * (plan §7.0 B). That is what lets `f5-skill-map` ship before a mastery
 * threshold exists: when the threshold is set it is a server-side rule and
 * `SkillGraph` does not change.
 *
 * Nothing in this package computes a state from a count, a ratio or a
 * threshold, and a referenced node with no declared state is a rejection
 * rather than a default.
 *
 * The four are the ones the documents name: `mastered`, `started` and `locked`
 * (plan §3.4) plus `available`, the fourth legend entry the `f5-skill-map` row
 * adds. `05`'s larger "current" node is which node the player is on, which is
 * a rendering question this format does not answer yet.
 */
export const SKILL_NODE_STATES = ["locked", "available", "started", "mastered"] as const;

export type SkillNodeState = (typeof SKILL_NODE_STATES)[number];

export const SkillNodeSchema = z.strictObject({
  skill_id: z.int().min(1),
  state: z.enum(SKILL_NODE_STATES),
});

export type SkillNode = z.infer<typeof SkillNodeSchema>;

/** The state the pack declared for this node, or nothing at all. */
export function declaredState(
  nodes: readonly SkillNode[],
  skillId: number,
): SkillNodeState | null {
  return nodes.find((node) => node.skill_id === skillId)?.state ?? null;
}
