/**
 * What a skill is called, in es-MX.
 *
 * **Here for the reason the diagnosis copy is here**: two consumers need the
 * same words — a pack's own presentation, and `GET /me/history`, which has to
 * put a `title` on an entry and has nothing else that knows what a skill is.
 * `skill_id` is a `smallint` in five tables and a name in none of them.
 *
 * **Keyed by the id, not by the template.** A skill outlives the templates that
 * exercise it: two families can drill the same one, and the name belongs to the
 * skill. `Template.skillId` is what connects them.
 *
 * Sparse on purpose. One skill exists, and inventing names for a map that does
 * not exist yet (F5) would be inventing the map.
 */
const SKILL_NAMES: Readonly<Record<number, string>> = Object.freeze({
  1: "Restas",
});

/**
 * The skill's name, or null where there is not one.
 *
 * **Null rather than a default.** A caller putting this on a screen needs to
 * know the difference between "this is called Restas" and "nobody has named
 * skill 7 yet" — a generic fallback chosen here would take that choice away
 * from the only place that can make it, which is the thing doing the writing.
 */
export function skillName(skillId: number): string | null {
  return SKILL_NAMES[skillId] ?? null;
}
