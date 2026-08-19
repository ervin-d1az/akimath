import { parsePuzzle } from "@akimath/contract";
import { describe, expect, it } from "vitest";

import {
  ATTEMPTS_PER_BOARD,
  generateKakuroBatch,
  type PuzzleCopy,
} from "../../src/puzzles/batch.js";
import { drawsFrom } from "../../src/puzzles/draw.js";
import { fillBoard, kakuroCandidate } from "../../src/puzzles/kakuro.js";

const COPY: PuzzleCopy = {
  tutorialSteps: ["Cada tramo suma el número de su pista."],
  referenceSheet: ["Dentro de un tramo no se repite ningún dígito."],
};

interface Cell {
  readonly row: number;
  readonly col: number;
}

interface Payload {
  readonly board: {
    readonly size: number;
    readonly blocked: readonly Cell[];
    readonly given: readonly Cell[];
    readonly solution: readonly (readonly number[])[];
  };
  readonly runs: readonly { readonly cells: readonly Cell[]; readonly sum: number }[];
}

const SEEDS = Array.from({ length: 40 }, (_, i) => i + 1);

/** Every candidate a run of seeds actually produced, refusals dropped. */
function made(size: number): Payload[] {
  return SEEDS.map((seed) => kakuroCandidate(BigInt(seed), size))
    .filter((c): c is { kind: 'kakuro'; payload: Record<string, unknown> } =>
      typeof c !== 'string')
    .map((c) => c.payload as unknown as Payload);
}

const key = (cell: Cell): string => `${cell.row},${cell.col}`;

describe("the clues are true by construction", () => {
  it("every run's sum is what its cells hold", () => {
    let checked = 0;
    for (const size of [3, 4, 5, 6]) {
      for (const payload of made(size)) {
        for (const run of payload.runs) {
          const total = run.cells.reduce(
            (sum, cell) => sum + payload.board.solution[cell.row]![cell.col]!,
            0,
          );
          expect(run.sum, `${size}×${size}`).toBe(total);
          checked += 1;
        }
      }
    }
    expect(checked, 'no candidate was produced at all').toBeGreaterThan(0);
  }, 120_000);

  it("no run repeats a digit", () => {
    // The format's own rule, and the one the fill exists to satisfy.
    for (const size of [3, 4, 5, 6]) {
      for (const payload of made(size)) {
        for (const run of payload.runs) {
          const values = run.cells.map(
            (cell) => payload.board.solution[cell.row]![cell.col]!,
          );
          expect(new Set(values).size).toBe(values.length);
        }
      }
    }
  }, 120_000);

  it("every open cell holds a digit from one to nine", () => {
    for (const payload of made(5)) {
      const blocked = new Set(payload.board.blocked.map(key));
      for (const [row, values] of payload.board.solution.entries()) {
        for (const [col, value] of values.entries()) {
          if (blocked.has(`${row},${col}`)) {
            continue;
          }
          expect(value).toBeGreaterThanOrEqual(1);
          expect(value).toBeLessThanOrEqual(9);
        }
      }
    }
  }, 120_000);
});

describe("runs cross, so coverage is not a partition", () => {
  it("every open cell is in at least one run", () => {
    // Unlike a cage, a Kakuro cell belongs to a horizontal run *and* a vertical
    // one, and a cell in neither can never be deduced — the contract calls that
    // `cage_coverage_incomplete`.
    for (const size of [3, 4, 5, 6]) {
      for (const payload of made(size)) {
        const covered = new Set(payload.runs.flatMap((r) => r.cells.map(key)));
        const blocked = new Set(payload.board.blocked.map(key));

        for (let row = 0; row < size; row += 1) {
          for (let col = 0; col < size; col += 1) {
            if (blocked.has(`${row},${col}`)) {
              continue;
            }
            expect(covered.has(`${row},${col}`), `${size}×${size} (${row},${col})`)
                .toBe(true);
          }
        }
      }
    }
  }, 120_000);

  it("a cell belonging to no run is refused by name, before the fill", () => {
    // The commonest refusal, and it has to be tellable from a solver rejection:
    // one means the blocked pattern was unlucky, the other means the board had
    // more than one answer.
    const refusals = SEEDS.map((seed) => kakuroCandidate(BigInt(seed), 5))
      .filter((c): c is string => typeof c === 'string');

    expect(refusals).toContain('a_cell_belongs_to_no_run');
  });

  it("some cells are in two runs, or this is not Kakuro", () => {
    // A board whose runs never crossed would be a row of unrelated sums.
    const payload = made(5)[0]!;
    const seen = new Map<string, number>();
    for (const run of payload.runs) {
      for (const cell of run.cells) {
        seen.set(key(cell), (seen.get(key(cell)) ?? 0) + 1);
      }
    }

    expect([...seen.values()].filter((n) => n >= 2).length).toBeGreaterThan(0);
  });

  it("every run is at least two cells", () => {
    for (const payload of made(4)) {
      for (const run of payload.runs) {
        expect(run.cells.length).toBeGreaterThanOrEqual(2);
      }
    }
  }, 120_000);
});

describe("a board that cannot be filled says so", () => {
  it("nine distinct digits do not cover a run of ten", () => {
    // Unreachable through `kakuroCandidate` — runs top out at six cells — which
    // is exactly why the guard is reachable from here instead. `drawBelow` was
    // split out of `intBetween` on the same reasoning.
    const run: Cell[] = [
      for0(0), for0(1), for0(2), for0(3),
      { row: 1, col: 0 }, { row: 1, col: 1 }, { row: 1, col: 2 }, { row: 1, col: 3 },
      { row: 2, col: 0 }, { row: 2, col: 1 },
    ];

    expect(
      fillBoard(4, () => false, [run], drawsFrom(1n)),
      isNullBecause('ten cells cannot hold ten distinct digits from nine'),
    ).toBeNull();
  });

  it("and an ordinary board fills", () => {
    // The control: without it the assertion above passes for a function that
    // always returns null.
    expect(
      fillBoard(
        4,
        () => false,
        [[for0(0), for0(1)], [{ row: 1, col: 0 }, { row: 1, col: 1 }]],
        drawsFrom(1n),
      ),
      'an easy board should fill',
    ).not.toBeNull();
  });
});

describe("what it prints", () => {
  it("never a blocked cell", () => {
    for (const payload of made(5)) {
      const blocked = new Set(payload.board.blocked.map(key));
      for (const cell of payload.board.given) {
        expect(blocked.has(key(cell))).toBe(false);
      }
    }
  }, 120_000);

  it("never the whole board", () => {
    for (const payload of made(5)) {
      const open = payload.board.size * payload.board.size -
          payload.board.blocked.length;
      expect(payload.board.given.length).toBeLessThan(open);
      expect(payload.board.given.length).toBeGreaterThan(0);
    }
  }, 120_000);

  it("a small board gives away less than a larger one", () => {
    // Measured: the jump is between 0.35 and 0.5, and the fraction that
    // rescues a 5×5 would hand a 3×3 over. Asserted against the *fraction*
    // rather than against one board's share, which varies with how many cells
    // the blocked pattern happened to take.
    const share = (size: number): number => {
      const payload = made(size)[0]!;
      const open = size * size - payload.board.blocked.length;
      return payload.board.given.length / open;
    };

    expect(share(3)).toBeCloseTo(0.35, 1);
    expect(share(5)).toBeCloseTo(0.5, 1);
  }, 120_000);

  it("the blocked cells come in a stable order", () => {
    // The pack is byte-diffed; a payload whose shape followed draw order would
    // make an unrelated regeneration look like a content change.
    for (const payload of made(5)) {
      const sorted = [...payload.board.blocked]
          .sort((a, b) => a.row - b.row || a.col - b.col);
      expect(payload.board.blocked).toEqual(sorted);
    }
  }, 120_000);
});

describe("a size outside the format is refused up front", () => {
  it("below three and above six", () => {
    expect(kakuroCandidate(1n, 2)).toBe('size_outside_the_format');
    expect(kakuroCandidate(1n, 7)).toBe('size_outside_the_format');
  });
});

describe("a batch", () => {
  it("every board it returns is accepted by the contract", () => {
    let boards = 0;
    for (const size of [3, 4, 5, 6]) {
      const batch = generateKakuroBatch({ size, count: 2, firstSeed: 1n }, COPY);

      expect(batch.report.exhausted, `size ${size}`).toBe(false);
      for (const board of batch.boards) {
        expect(parsePuzzle(board), `size ${size}`).toBeNull();
        expect(board.kind).toBe('kakuro');
      }
      boards += batch.boards.length;
    }
    console.log(`  kakuro generator · ${boards} boards, all accepted by parsePuzzle`);
    expect(boards).toBe(8);
  }, 300_000);

  it("an impossible size exhausts the budget, named", () => {
    const batch = generateKakuroBatch({ size: 7, count: 1, firstSeed: 1n }, COPY);

    expect(batch.boards).toEqual([]);
    expect(batch.report.refused)
        .toHaveProperty('size_outside_the_format', ATTEMPTS_PER_BOARD);
  });

  it("the same request is the same boards", () => {
    const request = { size: 4, count: 2, firstSeed: 3n } as const;
    expect(generateKakuroBatch(request, COPY).boards).toEqual(
      generateKakuroBatch(request, COPY).boards,
    );
  });
});

/** A cell in row zero. Shorthand, so the ten-cell run above stays readable. */
function for0(col: number): Cell {
  return { row: 0, col };
}

/** Reads as a reason in a failure message. */
function isNullBecause(why: string): string {
  return why;
}
