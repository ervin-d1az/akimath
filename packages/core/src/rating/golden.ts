import { decay } from "./decay.js";
import { rateSession, type Outcome, type Skill } from "./glicko.js";

/**
 * The rating's committed vector.
 *
 * Byte-exact despite floating point, because every figure is narrowed to the
 * float32 the schema stores — which absorbs far more error than an engine's
 * `Math.pow` introduces. `test/rating/glicko.test.ts` measures that margin
 * rather than assuming it.
 */
export interface RatingGolden {
  readonly sessions: ReadonlyArray<{
    readonly prior: Skill;
    readonly outcomes: readonly Outcome[];
    readonly after: Skill;
  }>;
  readonly decays: ReadonlyArray<{
    readonly prior: Skill;
    readonly elapsedDays: number;
    readonly after: Skill;
  }>;
}

const PRIORS: readonly Skill[] = [
  { rating: 1500, deviation: 350 },
  { rating: 1500, deviation: 200 },
  { rating: 1200, deviation: 80 },
  { rating: 1900, deviation: 50 },
];

const SESSIONS: ReadonlyArray<readonly Outcome[]> = [
  [{ opponentRating: 1500, opponentDeviation: 200, score: 1 }],
  [{ opponentRating: 1500, opponentDeviation: 200, score: 0 }],
  [
    { opponentRating: 1400, opponentDeviation: 30, score: 1 },
    { opponentRating: 1550, opponentDeviation: 100, score: 0 },
    { opponentRating: 1700, opponentDeviation: 300, score: 0 },
  ],
  [
    { opponentRating: 1000, opponentDeviation: 120, score: 1 },
    { opponentRating: 1000, opponentDeviation: 120, score: 1 },
    { opponentRating: 1000, opponentDeviation: 120, score: 0.5 },
  ],
];

const ELAPSED: readonly number[] = [0, 1, 7, 30, 365, 1000];

export function buildRatingGolden(): RatingGolden {
  return {
    sessions: PRIORS.flatMap((prior) =>
      SESSIONS.map((outcomes) => ({
        prior,
        outcomes,
        after: rateSession(prior, outcomes),
      })),
    ),
    decays: PRIORS.flatMap((prior) =>
      ELAPSED.map((elapsedDays) => ({
        prior,
        elapsedDays,
        after: decay(prior, elapsedDays),
      })),
    ),
  };
}
