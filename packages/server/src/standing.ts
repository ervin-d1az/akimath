import type { Response } from "./routing.js";

/**
 * What `GET /me/standing` answers.
 *
 * **PURE** — rows in, the frozen `Standing` out. The repository beside this
 * fetches; every rule about the *answer* is here, where it is tested by
 * comparing two objects.
 *
 * **The frozen shape carries a rating and nothing else.** `Standing` is a
 * `playerId` and a list of `{skillId, rating, deviation, updatedAt}`. It has no
 * field for accuracy and none for time on task, so neither can be answered
 * here however derivable they are from `attempts` — putting them in would mean
 * emitting properties the document forbids (`additionalProperties: false`), and
 * the contract is authoritative. Carrying them is a contract decision, and it
 * is not this module's to make.
 *
 * **The list is empty until the player has been measured, and that is now a
 * fact about them rather than about the server.** `POST /attempts` writes
 * `user_skills` — see `rating.ts` — so a row appears as soon as a session is
 * rated against a difficulty class the players have already measured. A player
 * whose every answer met an unmeasured class still gets `[]`, because there was
 * no evidence to rate them against; that is the same reading this module always
 * took, kept honest now that a number is available.
 */

/** One `user_skills` row, as the repository hands it over. */
export interface SkillRating {
  readonly skillId: number;
  readonly rating: number;
  readonly deviation: number;
  readonly updatedAt: Date;
}

/**
 * The frozen `Standing` for one player.
 *
 * **An unrated player gets an empty list, not a 404 and not a zero.** `rating`
 * is required *and* not nullable in the frozen schema, so unlike
 * `GET /me/history`'s `ratingDelta` there is no null to answer with — the
 * absence of a rating is the absence of an entry, and the empty array is how
 * the shape spells it. A 404 would say the player does not exist, which is a
 * different and untrue thing.
 *
 * **The order is the repository's.** Sorting here would be a second opinion
 * about an order the query already decided, the same reading `historyResponse`
 * takes of "newest first".
 *
 * `updatedAt` is emitted with `toISOString`, which is the one `Date` method
 * producing the milliseconds and the `Z` the frozen `date-time` pattern
 * requires — pinned at the field it governs, as `profileResponse` pins
 * `createdAt`.
 */
export function standingResponse(
  playerId: string,
  ratings: readonly SkillRating[],
): Response {
  return {
    status: 200,
    body: {
      playerId,
      skills: ratings.map((skill) => ({
        skillId: skill.skillId,
        rating: skill.rating,
        deviation: skill.deviation,
        updatedAt: skill.updatedAt.toISOString(),
      })),
    },
  };
}
