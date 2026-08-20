import type { TemplateRef } from "./template.js";

/**
 * How a `TemplateRef` is written down, and read back.
 *
 * **PURE**, and it exists because two packages had to agree about this shape
 * and neither owned it. `offline_packs.template_refs` is a `jsonb` array of
 * these; the pack builder will write them when something issues a pack, and
 * `packages/server`'s `refForPackItem` already reads them. Until now the reader
 * matched a comment in `ARCHITECTURE.md` rather than a producer, so a mismatch
 * would have surfaced as `refForPackItem` returning null for every real pack —
 * a 404 that looks exactly like a missing row.
 *
 * **The seed is a string, and that is not a style choice.** `jsonb` is read
 * with `JSON.parse`, which loses a bigint above 2^53:
 * `1477776061723855037` comes back as `1477776061723855000`. Migration 0002
 * refuses a numeric seed inside `template_refs` for that reason, and this is
 * the code side of the same rule. Splitmix64 avalanches, so a seed off by one
 * rederives an unrelated item rather than a similar one — and every schema is
 * perfectly happy with the result.
 *
 * **snake_case**, matching the column and the pack format. A response shape is
 * camelCase and neither is renamed to match the other.
 */
export interface ManifestEntry {
  readonly template_id: string;
  readonly template_version: number;
  /** The `bigint` seed, decimal, as a string. Never a JSON number. */
  readonly seed: string;
  readonly ladder_step: number;
}

/** A reference, written down. */
export function toManifestEntry(ref: TemplateRef): ManifestEntry {
  return {
    template_id: ref.templateId,
    template_version: ref.templateVersion,
    seed: ref.seed.toString(),
    ladder_step: ref.ladderStep,
  };
}

/**
 * A reference read back, or null if the entry is not one.
 *
 * **Null rather than a throw.** The caller is a request handler holding a
 * manifest it did not write; a malformed entry is the server's problem, and
 * answering "no such item" is recoverable where a 500 for the whole batch is
 * not. A *reference the registry cannot resolve* is the other thing entirely
 * and does throw — see `resolve`.
 */
export function fromManifestEntry(value: unknown): TemplateRef | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const entry = value as Record<string, unknown>;
  const { template_id, template_version, seed, ladder_step } = entry;
  if (
    typeof template_id !== "string" ||
    typeof template_version !== "number" ||
    !Number.isInteger(template_version) ||
    // A number here is the bug migration 0002 exists to prevent, and it has
    // already lost precision by the time it reaches this function — so it is
    // refused rather than converted.
    typeof seed !== "string" ||
    !/^-?\d+$/.test(seed) ||
    typeof ladder_step !== "number" ||
    !Number.isInteger(ladder_step)
  ) {
    return null;
  }
  return {
    templateId: template_id,
    templateVersion: template_version,
    seed: BigInt(seed),
    ladderStep: ladder_step,
  };
}
