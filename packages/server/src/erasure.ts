import type { HandlerAnswer } from "./routing.js";

/**
 * What `DELETE /me` answers, given whether there was a player to erase.
 *
 * **PURE** — a boolean in, a status out. The deleting is
 * `adapters/player-repository.ts`; every rule about the *answer* is here, where
 * it is two objects to compare.
 *
 * **What this endpoint erases, and what it does not.** It deletes the `players`
 * row, and the five tables that reference it go with it by `ON DELETE CASCADE`:
 * `attempts`, `issued_items`, `offline_packs`, `user_skills`, `diag_events`.
 * `template_stats` survives, because it carries no player id — it is the
 * aggregate that lets calibration outlive the retention job deleting raw
 * attempts.
 *
 * It does **not** delete the Neon Auth account. That identity lives in the
 * provider's `neon_auth` schema; this service holds no credential that could
 * remove it, so the email and the sign-in survive this call. The contract says
 * so in the operation's description rather than leaving the caller to infer it
 * from a 204.
 */

/**
 * 204 when a player was erased, 404 when the account never had one.
 *
 * **Not 204 both times.** Idempotence would argue for it, and it would also
 * hide the one bug this endpoint can have: a client erasing under an account
 * that is not the one it thinks it is holds a session, gets "done", and never
 * finds out its data is still there. The second call is a different question
 * from the first and gets a different answer.
 *
 * A separate message from `profileResponse`'s 404, which sends the caller to
 * `POST /players/link` — advice that reads as a taunt right after somebody
 * asked to be forgotten.
 */
export function erasureResponse(erased: boolean): HandlerAnswer {
  if (erased) {
    return { status: 204 };
  }
  return {
    status: 404,
    body: {
      error: "no_player",
      message: "This account has no player, so there is nothing to erase.",
    },
  };
}
