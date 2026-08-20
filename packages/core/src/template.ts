import type { Rational } from "./rational.js";

/**
 * What the schema records about an issued item, and therefore everything
 * rederivation is allowed to depend on.
 *
 * **Four fields, not three.** `ARCHITECTURE.md` §3 says the server rederives
 * from `(template_id, template_version, seed)`, and
 * `packages/server/migrations/0001_initial.sql` declares `issued_items` with
 * `ladder_step smallint NOT NULL` beside those three. The migration is applied
 * and forward-only, so the schema is the authority and the document was
 * corrected. Nothing in a seed says which ladder step an item was issued at,
 * which is exactly why the column exists.
 */
export interface TemplateRef {
  readonly templateId: string;
  /** Integer, ≥ 1. Bumped when behaviour changes; old versions never edited. */
  readonly templateVersion: number;
  /** The Postgres `bigint` column, signed. */
  readonly seed: bigint;
  /** 1–20, matching the frozen item schema. */
  readonly ladderStep: number;
}

/** A rendered prompt token, structurally what the pack format carries. */
export type PromptToken =
  | { readonly kind: "text"; readonly value: string }
  | { readonly kind: "operator"; readonly glyph: string };

/** One term of an arithmetic stimulus, as the frozen payload spells it. */
export interface Term {
  readonly num: number;
  readonly den: number;
}

/**
 * What a template produces.
 *
 * It carries the **exact** answer as a `Rational` and never a string: rendering
 * belongs to `packages/contract`, which already owns what `5/4` looks like and
 * is checked against Dart on the same fixture. It carries no digest and no
 * diagnosis either — a digest needs a pack salt, and a diagnosis is authored
 * content. Both are the pack builder's, at F1.5.
 */
export interface GeneratedItem {
  readonly prompt: readonly PromptToken[];
  readonly answer: Rational;
  readonly ladderStep: number;
  /** The arithmetic payload, for the frozen stimulus envelope. */
  readonly operator: "+" | "-" | "×" | "÷";
  readonly left: Term;
  readonly right: Term;
}

/**
 * One version of one template.
 *
 * **A version is a separate object, never an edited one.** An attempt recorded
 * in 2026 must rederive in 2029 exactly as it did, so a revision adds a version
 * rather than changing behaviour under the old number. `retired` stops a version
 * being issued again while leaving it fully rederivable — the two are different
 * questions and conflating them is how history gets rewritten.
 */
export interface Template {
  readonly id: string;
  readonly version: number;
  /**
   * Which skill this version exercises. Integer, ≥ 1.
   *
   * **Here rather than in the pack declaration or the schema.**
   * `attempts.skill_id` is `NOT NULL` and nothing on the wire supplies it — an
   * attempt names an item, and an item is a `TemplateRef`. Neither
   * `issued_items` nor `offline_packs.template_refs` records a skill either. So
   * the server derives it, and the only thing in a recorded reference that
   * knows is the template.
   *
   * **Per version, not per template.** Reclassifying a skill is a behaviour
   * change and therefore a new version, never an edit — and an attempt keeps
   * the skill it was rated against, because `attempts.skill_id` is stored
   * rather than re-derived.
   */
  readonly skillId: number;
  readonly retired?: boolean;
  readonly generate: (ref: TemplateRef) => GeneratedItem;
}
