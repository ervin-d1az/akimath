import type { Response } from "./routing.js";

/**
 * What `GET /me` answers, given what the database had.
 *
 * **PURE** — a row in, a status and a body out. No client, no clock, no
 * connection: the repository beside this fetches, and every rule about the
 * *answer* is here where it can be tested by comparing two objects.
 */

/** A `players` row, as the repository hands it over. */
export interface PlayerRow {
  readonly id: string;
  readonly age_band: string;
  readonly created_at: Date;
}

/**
 * The profile of the player linked to the session, or a 404.
 *
 * **404 and not 401.** The caller authenticated; there is simply no player
 * under that account yet, which is the ordinary state of an adult who has
 * created an account and not linked a device. Answering 401 would send a client
 * with a perfectly good session off to fetch another one, forever.
 *
 * **`createdAt` is emitted with milliseconds and a `Z`.** The frozen `Me` schema
 * pins `date-time` to a pattern that requires both, and `toISOString` is the one
 * `Date` method that produces exactly it — `toJSON` agrees today, and pinning
 * the call here rather than relying on `JSON.stringify` keeps the contract's
 * requirement visible next to the field it governs.
 */
export function noPlayerResponse(): Response {
  return {
    status: 404,
    body: {
      error: "no_player",
      message: "This account has no player yet. Link one with POST /players/link.",
    },
  };
}

export function profileResponse(row: PlayerRow | null): Response {
  if (row === null) {
    return noPlayerResponse();
  }

  return {
    status: 200,
    body: {
      playerId: row.id,
      ageBand: row.age_band,
      createdAt: row.created_at.toISOString(),
    },
  };
}
