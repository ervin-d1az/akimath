import { decay, initialSkill, rateSession, type Outcome, type Skill } from "@akimath/core";

/**
 * What a batch of answered items does to a rating.
 *
 * **PURE** — landed attempts and the priors they meet in, new rows out. No
 * clock (`now` is an argument), no database, no randomness, so every decision
 * below is tested by comparing two objects. The repository beside this fetches
 * and writes; `@akimath/core` owns the arithmetic.
 *
 * Three of the four decisions a rating needs were taken before this file
 * existed and are cited rather than restated, because a restatement goes stale
 * where the original does not (CMT-2):
 *
 *   · **Glicko-1, not Glicko-2** — `packages/core/src/rating/glicko.ts`, decided
 *     by the schema: `user_skills` carries no volatility column.
 *   · **The rating period is the session** — `ARCHITECTURE.md` §3.
 *   · **1500 and 350 for something nobody has met** — Glickman's own defaults,
 *     `initialSkill()`.
 *
 * The fourth was left open on purpose. `glicko.ts` says "core decides nothing
 * about where an opponent rating comes from", and this module is where it is
 * decided.
 *
 * ## What plays the opponent
 *
 * **The difficulty class `(skill_id, ladder_step)`, rated on the same scale as
 * a player and measured from the players who met it.**
 *
 * The step is an *identity*, never a rating. It is a 1..20 ordinal the content
 * author writes; the frozen pack schema requires it on every item and
 * `issued_items` records it on every issuance, so it is a name every gradeable
 * item already has. What it is *worth* is not written down anywhere — placing
 * it on the rating scale would take an origin and a spacing that no recorded
 * evidence supports, and that invented scale is what F4 was held back to avoid.
 *
 * So the class is rated the way a player is: every answer is one game between
 * the two, scored from the player's side and mirrored for the class. A class
 * that beats strong players becomes strong. The scale's only anchor is
 * Glickman's 1500 for an entity nobody has met, which is a citation rather than
 * a figure chosen to make the numbers look right.
 *
 * ## What is deliberately left unrated
 *
 * **An answer against a class nobody has measured does not move the player.**
 * With no evidence about the item, the observation is one equation in two
 * unknowns; resolving it by assuming a difficulty would make the rating a
 * function of accuracy alone while looking like a measurement. The answer still
 * *teaches the class*, so the evidence is kept and the next player is rated
 * against it — `calibrating` counts what this cost.
 *
 * **An answer whose item records no difficulty at all is rated by nothing.** A
 * pack row naming no content has no step to read. `unplaced` counts those; they
 * are reported rather than silently absorbed, because a bulk operation that
 * skips work in silence reads as success.
 *
 * **Both counters are returned and, today, read only by tests.** `createHandlers`
 * is built without a logger, so there is nowhere inside the request for them to
 * surface; wiring them into the request log line is deliberately left for the
 * change that gives handlers a logger. Saying so here rather than leaving the
 * gap implicit: the numbers are computed and asserted, but no operator can see
 * them yet.
 */

/** A day, in milliseconds. `decay` counts in days (`ARCHITECTURE.md` §3). */
const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** One landed answer, as the rating sees it. */
export interface RatedAttempt {
  readonly sessionId: string;
  readonly skillId: number;
  /** Null when nothing recorded about the item names a difficulty. */
  readonly ladderStep: number | null;
  readonly isCorrect: boolean;
  readonly answeredAt: Date;
}

/** A stored player rating, with when the server last measured it. */
export interface StoredSkill extends Skill {
  readonly updatedAt: Date;
}

/** One session of one skill — the unit Glicko calls a rating period. */
export interface RatingPeriod {
  readonly sessionId: string;
  readonly skillId: number;
  readonly attempts: readonly RatedAttempt[];
  /** The last answer in it, which is when the period reads as having ended. */
  readonly endedAt: Date;
}

export interface RatedSkill {
  readonly skillId: number;
  readonly rating: number;
  readonly deviation: number;
}

/**
 * What one rating period did to one skill's rating.
 *
 * **Recorded here because here is the only place it is knowable.** A delta is
 * a difference between two instants, and the earlier one stops existing the
 * moment this returns: the classes the period was rated against move on the
 * very next batch, so replaying the same answers tomorrow produces a different
 * figure. Nothing downstream can recover it, which is why `GET /me/history`
 * answered null for it until this existed.
 *
 * **Only a period that ran the engine has one**, and the reason is the wire
 * type rather than a preference: the frozen `HistoryEntry.ratingDelta` is a
 * nullable *integer*, so a measured change of a third of a point already
 * renders as `0`. If a period that measured nothing also rendered `0`, "we did
 * not measure you" and "we measured you and you held" would be the same value
 * on the wire — and those are two different facts about a session. A period
 * that only calibrated is therefore absent from this list, and absent becomes
 * null.
 *
 * The change is kept unrounded: `user_skills` is `real` and this is the
 * difference between two of them. Rounding is a presentation decision and it
 * belongs where the presentation is, in `history.ts`.
 */
export interface SessionDelta {
  readonly sessionId: string;
  readonly skillId: number;
  /** The movement on the rating scale — signed, and never rounded. */
  readonly change: number;
}

export interface RatedDifficulty extends RatedSkill {
  readonly ladderStep: number;
}

export interface RatingInputs {
  readonly attempts: readonly RatedAttempt[];
  /** The player's stored ratings, by skill. Absent means never rated. */
  readonly skills: ReadonlyMap<number, StoredSkill>;
  /** The measured classes, by `difficultyKey`. Absent means never measured. */
  readonly difficulties: ReadonlyMap<string, Skill>;
  readonly now: Date;
}

export interface RatingUpdate {
  /** Only the skills this batch actually moved. */
  readonly skills: readonly RatedSkill[];
  /** Only the classes this batch actually observed. */
  readonly difficulties: readonly RatedDifficulty[];
  /** One per rating period that moved the player, in the order they happened. */
  readonly deltas: readonly SessionDelta[];
  /** Answers whose item names no difficulty, so nothing could rate them. */
  readonly unplaced: number;
  /** Answers that taught a class rather than moving the player. */
  readonly calibrating: number;
}

/**
 * How a difficulty class is named in a map.
 *
 * A string because `Map` compares object keys by identity, and the pair has to
 * survive a round trip through the repository that reads it.
 */
export function difficultyKey(skillId: number, ladderStep: number): string {
  return `${skillId}:${ladderStep}`;
}

/**
 * How long a prior has gone unmeasured, in days and never negative.
 *
 * **Clamped rather than guarded at the call site.** `decay` refuses a negative
 * span, and a stored `updated_at` a moment ahead of this transaction's `now` is
 * ordinary clock skew between a database and a process — not a reason to fail
 * a sync a player is waiting on.
 */
export function elapsedDays(from: Date, to: Date): number {
  // `Math.max` rather than a comparison, because `span <= 0 ? 0 : …` and
  // `span < 0 ? 0 : …` compute the same thing — zero divided by a day is zero —
  // so the boundary was an equivalent mutant no test could ever kill. Removing
  // the branch removes the question.
  return Math.max(0, to.getTime() - from.getTime()) / MS_PER_DAY;
}

/**
 * The batch, cut into rating periods, oldest first.
 *
 * **By session *and* by skill.** The session is `ARCHITECTURE.md` §3's decision
 * and the skill is forced by the table: `user_skills` is one row per
 * `(player_id, skill_id)`, so a period spanning two skills has nowhere to be
 * written. Grouping by the batch instead would silently restore the
 * per-request grouping §3 rejects — a device that synced twice would rate
 * differently from one that synced once, in the app whose promise is fair
 * adaptive difficulty.
 *
 * **Ordered by when each period ended**, because successive sessions are
 * successive rating periods and a week of offline play arrives in one request.
 * The key breaks ties, so a batch whose answers share an instant still has one
 * order rather than the insertion order of a `Map`.
 */
export function ratingPeriods(attempts: readonly RatedAttempt[]): readonly RatingPeriod[] {
  const grouped = new Map<string, RatedAttempt[]>();
  for (const attempt of attempts) {
    // A space separates them unambiguously: `readAttemptBatch` has already held
    // the session to the uuid pattern, which admits no space, so there is
    // exactly one place this key can be cut.
    const key = `${attempt.sessionId} ${attempt.skillId}`;
    const already = grouped.get(key);
    if (already === undefined) {
      grouped.set(key, [attempt]);
    } else {
      already.push(attempt);
    }
  }

  return [...grouped]
    .map(([key, group]) => ({
      key,
      period: {
        sessionId: group[0]!.sessionId,
        skillId: group[0]!.skillId,
        attempts: group as readonly RatedAttempt[],
        endedAt: new Date(Math.max(...group.map((a) => a.answeredAt.getTime()))),
      },
    }))
    .sort(
      (left, right) =>
        left.period.endedAt.getTime() - right.period.endedAt.getTime() ||
        left.key.localeCompare(right.key),
    )
    .map(({ period }) => period);
}

/**
 * What this batch does to the player and to the classes it met.
 *
 * The two updates are computed from **the same pre-period player**, so one
 * observation cannot leave the player and the class disagreeing about who was
 * playing — and the loop's own order stops mattering, which is what makes a
 * period a set rather than a sequence.
 */
export function rateAttempts(inputs: RatingInputs): RatingUpdate {
  const skills = new Map<number, Skill>();
  const moved = new Set<number>();
  const difficulties = new Map(inputs.difficulties);
  const measured = new Set<string>();
  const deltas: SessionDelta[] = [];
  let unplaced = 0;
  let calibrating = 0;

  for (const period of ratingPeriods(inputs.attempts)) {
    const before = priorFor(skills, inputs, period.skillId);

    const playerOutcomes: Outcome[] = [];
    const byClass = new Map<string, RatedAttempt[]>();

    for (const attempt of period.attempts) {
      if (attempt.ladderStep === null) {
        unplaced += 1;
        continue;
      }
      const key = difficultyKey(attempt.skillId, attempt.ladderStep);
      const against = difficulties.get(key);
      if (against === undefined) {
        // No evidence about this class yet, so the answer says nothing about
        // the player — only about the class.
        calibrating += 1;
      } else {
        playerOutcomes.push({
          opponentRating: against.rating,
          opponentDeviation: against.deviation,
          score: attempt.isCorrect ? 1 : 0,
        });
      }
      const already = byClass.get(key);
      if (already === undefined) {
        byClass.set(key, [attempt]);
      } else {
        already.push(attempt);
      }
    }

    if (playerOutcomes.length > 0) {
      const after = rateSession(before, playerOutcomes);
      skills.set(period.skillId, after);
      moved.add(period.skillId);
      // Against `before` and not against the stored row: `before` is the
      // decayed prior the engine was actually handed, so this is the movement
      // that happened rather than the difference from a figure nothing used.
      deltas.push({
        sessionId: period.sessionId,
        skillId: period.skillId,
        change: after.rating - before.rating,
      });
    }

    for (const [key, answers] of byClass) {
      const classPrior = difficulties.get(key) ?? initialSkill();
      difficulties.set(
        key,
        // Mirrored: the class wins exactly when the player did not. Its
        // opponent is the player as they stood before this period.
        rateSession(
          classPrior,
          answers.map((attempt) => ({
            opponentRating: before.rating,
            opponentDeviation: before.deviation,
            score: attempt.isCorrect ? 0 : 1,
          })),
        ),
      );
      measured.add(key);
    }
  }

  return {
    // **Only what moved.** Rewriting an untouched row with the same numbers
    // still moves `updated_at`, and `updated_at` is what `decay` reads — a
    // no-op write would reset the clock on a rating nobody measured.
    skills: [...moved].map((skillId) => ({ skillId, ...skills.get(skillId)! })),
    difficulties: [...measured].map((key) => ({
      ...classOf(key),
      ...difficulties.get(key)!,
    })),
    deltas,
    unplaced,
    calibrating,
  };
}

/**
 * The player's strength at the start of the first period that needs it.
 *
 * **Decayed once, from the last time the server measured to now.** Glickman's
 * Step 1 is the growth of uncertainty between rating periods, and with the
 * session as the period a player who never opens the app has no periods at all
 * — so `ARCHITECTURE.md` §3 counts it in days. Measuring the span against
 * `now` rather than against the session's own timestamp keeps it monotonic:
 * the span is always server-observed time, and a client's clock cannot shorten
 * or reverse it.
 *
 * Later periods in the same batch read the working value, because by then the
 * player has been measured — inside one batch, no time passes.
 */
function priorFor(
  working: ReadonlyMap<number, Skill>,
  inputs: RatingInputs,
  skillId: number,
): Skill {
  // Only read, never written: a period that moves the skill writes it back
  // itself, and a period that does not leaves nothing worth remembering —
  // recomputing gives the same figure, because `decay` is a function of the
  // stored row and one `now`. Caching it here would be a line no test could
  // ever falsify.
  const already = working.get(skillId);
  if (already !== undefined) {
    return already;
  }
  const stored = inputs.skills.get(skillId);
  return stored === undefined
    ? initialSkill()
    : decay(
        { rating: stored.rating, deviation: stored.deviation },
        elapsedDays(stored.updatedAt, inputs.now),
      );
}

/** The pair a `difficultyKey` was built from. */
function classOf(key: string): { readonly skillId: number; readonly ladderStep: number } {
  const [skillId, ladderStep] = key.split(":").map(Number);
  return { skillId: skillId!, ladderStep: ladderStep! };
}
