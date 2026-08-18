import { parsePuzzle, type PuzzleEnvelope, type PuzzleRejectionTag } from "@akimath/contract";

import { cagedCandidate, type CagedKind } from "./caged.js";

/**
 * How many seeds one board may cost before the request is abandoned.
 *
 * Bounded, because a request that cannot be satisfied — a size whose candidates
 * are never unique, say — must stop rather than search forever.
 */
export const ATTEMPTS_PER_BOARD = 200;

export interface BatchRequest {
  readonly kind: CagedKind;
  readonly size: number;
  readonly count: number;
  readonly firstSeed: bigint;
}

export interface BatchReport {
  readonly attempts: number;
  readonly accepted: number;
  /** How many candidates each rejection tag accounted for. */
  readonly refused: Readonly<Record<string, number>>;
  /** True when the budget ran out before `count` boards were found. */
  readonly exhausted: boolean;
}

export interface Batch {
  readonly boards: readonly PuzzleEnvelope[];
  readonly report: BatchReport;
}

/**
 * A batch of caged boards, every one of them accepted by the frozen contract.
 *
 * **Propose and dispose** (design D1). A refused candidate is dropped and the
 * next seed tried; it is never adjusted until it passes, because knowing what
 * would fix it means owning a second solver.
 *
 * **The report is part of the return value** (design D5), not a log line. A
 * generator that quietly produces four boards when asked for ten looks exactly
 * like one that was asked for four, and the difference matters the moment
 * someone widens the size range and the hit rate collapses.
 */
export function generateCagedBatch(
  request: BatchRequest,
  copy: PuzzleCopy,
): Batch {
  const boards: PuzzleEnvelope[] = [];
  const refused: Record<string, number> = {};
  const budget = request.count * ATTEMPTS_PER_BOARD;
  let attempts = 0;
  let seed = request.firstSeed;

  while (boards.length < request.count && attempts < budget) {
    attempts += 1;
    const seedUsed = seed;
    seed += 1n;

    const candidate = cagedCandidate(request.kind, seedUsed, request.size);
    if (candidate === null) {
      // Killer only: a cage the Latin square gave a repeated digit. Counted
      // under its own name rather than folded into the contract's tags, so a
      // collapse in hit rate can be told apart from a contract rejection.
      refused["repeated_digit_in_cage"] = (refused["repeated_digit_in_cage"] ?? 0) + 1;
      continue;
    }

    const envelope: PuzzleEnvelope = {
      kind: candidate.kind,
      payload: candidate.payload,
      tutorial_steps: [...copy.tutorialSteps],
      reference_sheet: [...copy.referenceSheet],
    };

    const tag: PuzzleRejectionTag | null = parsePuzzle(envelope);
    if (tag !== null) {
      refused[tag] = (refused[tag] ?? 0) + 1;
      continue;
    }
    boards.push(envelope);
  }

  return {
    boards,
    report: {
      attempts,
      accepted: boards.length,
      refused,
      exhausted: boards.length < request.count,
    },
  };
}

/** The es-MX text every puzzle carries, supplied by the caller. */
export interface PuzzleCopy {
  readonly tutorialSteps: readonly string[];
  readonly referenceSheet: readonly string[];
}
