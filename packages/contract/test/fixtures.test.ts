import { describe, expect, it } from "vitest";

import { goldenStems, readFixture } from "./fixture-files.js";
import { parsePack } from "../src/pack.js";

import { checkArithmetic, ArithmeticPayloadSchema } from "../src/stimulus/arithmetic.js";
import { checkAnalogy, AnalogyPayloadSchema } from "../src/stimulus/analogy.js";
import { checkFigurate, FiguratePayloadSchema } from "../src/stimulus/figurate.js";
import { checkHiddenOperation, HiddenOperationPayloadSchema } from "../src/stimulus/hidden-operation.js";
import {
  checkBlockedCells,
  checkCageCoverage,
  checkGivenCells,
  checkRunCoverage,
  checkSolutionShape,
  checkSumReachable,
} from "../src/puzzle/board.js";
import { checkKakuro, KakuroPayloadSchema } from "../src/puzzle/kakuro.js";
import { checkKenKen, KenKenPayloadSchema, type KenKenPayload } from "../src/puzzle/kenken.js";
import { checkKiller, KillerPayloadSchema } from "../src/puzzle/killer.js";
import { PUZZLE_KINDS, parsePuzzle, PuzzleEnvelopeSchema } from "../src/puzzle/index.js";
import { checkMagicSquare, MagicSquarePayloadSchema } from "../src/puzzle/magic-square.js";
import { checkWordSearch, WordSearchPayloadSchema } from "../src/puzzle/word-search.js";
import {
  checkUniqueSolution,
  latinRegions,
  searchSolutions,
  SEARCH_NODE_BUDGET,
  type ConstraintProblem,
} from "../src/puzzle/uniqueness.js";
import { parseStimulus, STIMULUS_KINDS, StimulusEnvelopeSchema } from "../src/stimulus/index.js";
import { checkMatrix, MatrixPayloadSchema } from "../src/stimulus/matrix.js";
import { checkNumberSeries, NumberSeriesPayloadSchema } from "../src/stimulus/number-series.js";

describe("the stimulus envelope", () => {
  it("closes at the six kinds of the sealed Stimulus type", () => {
    expect(STIMULUS_KINDS).toEqual([
      "arithmetic",
      "numberSeries",
      "matrix",
      "analogy",
      "hiddenOperation",
      "figurate",
    ]);
  });

  it("accepts a known kind carrying an opaque payload", () => {
    expect(
      StimulusEnvelopeSchema.safeParse({ kind: "arithmetic", payload: { anything: 1 } }).success,
    ).toBe(true);
  });

  it("rejects a seventh kind", () => {
    expect(StimulusEnvelopeSchema.safeParse({ kind: "wordProblem", payload: {} }).success).toBe(
      false,
    );
  });

  it("rejects a stimulus with no payload", () => {
    expect(StimulusEnvelopeSchema.safeParse({ kind: "matrix" }).success).toBe(false);
  });

  it("rejects a payload that is not an object", () => {
    expect(StimulusEnvelopeSchema.safeParse({ kind: "matrix", payload: [1, 2, 3] }).success).toBe(
      false,
    );
  });

  it("rejects a field smuggled beside the envelope", () => {
    expect(
      StimulusEnvelopeSchema.safeParse({ kind: "matrix", payload: {}, seed: 42 }).success,
    ).toBe(false);
  });
});

describe("the arithmetic payload", () => {
  it("accepts a fraction sum, the item 04 Error diagnoses", () => {
    const parsed = ArithmeticPayloadSchema.safeParse({
      operator: "+",
      left: { num: 1, den: 2 },
      right: { num: 1, den: 3 },
    });
    expect(parsed.success).toBe(true);
  });

  it("rejects a term with a zero denominator", () => {
    expect(
      ArithmeticPayloadSchema.safeParse({
        operator: "+",
        left: { num: 1, den: 0 },
        right: { num: 1, den: 3 },
      }).success,
    ).toBe(false);
  });

  it("rejects a fifth operator", () => {
    expect(
      ArithmeticPayloadSchema.safeParse({
        operator: "^",
        left: { num: 1, den: 1 },
        right: { num: 2, den: 1 },
      }).success,
    ).toBe(false);
  });

  it("rejects a division by a zero-valued term", () => {
    expect(
      checkArithmetic({ operator: "÷", left: { num: 3, den: 4 }, right: { num: 0, den: 5 } }),
    ).toBe("division_by_zero_term");
  });

  it("accepts a division by a non-zero term", () => {
    expect(
      checkArithmetic({ operator: "÷", left: { num: 3, den: 4 }, right: { num: 1, den: 5 } }),
    ).toBeNull();
  });
});

describe("the numberSeries payload", () => {
  it("accepts a seven-term series with one unknown tile", () => {
    expect(
      NumberSeriesPayloadSchema.safeParse({ terms: [2, 4, 8, 16, 32], unknown_index: 4 }).success,
    ).toBe(true);
  });

  it("rejects a series shorter than three terms", () => {
    expect(NumberSeriesPayloadSchema.safeParse({ terms: [2, 4], unknown_index: 1 }).success).toBe(
      false,
    );
  });

  it("rejects a series longer than the seven tiles the design draws", () => {
    expect(
      NumberSeriesPayloadSchema.safeParse({ terms: [1, 2, 3, 4, 5, 6, 7, 8], unknown_index: 0 })
        .success,
    ).toBe(false);
  });

  it("rejects an unknown tile outside the series", () => {
    expect(checkNumberSeries({ terms: [2, 4, 8], unknown_index: 3 })).toBe(
      "unknown_index_out_of_range",
    );
  });

  it("accepts an unknown tile inside the series", () => {
    expect(checkNumberSeries({ terms: [2, 4, 8], unknown_index: 2 })).toBeNull();
  });
});

describe("the matrix payload", () => {
  it("accepts a 3×3 matrix with one unknown cell", () => {
    expect(
      MatrixPayloadSchema.safeParse({ size: 3, cells: [1, 2, 3, 4, 5, 6, 7, 8, 9], unknown_index: 8 })
        .success,
    ).toBe(true);
  });

  it("rejects a cell count that does not match the declared size", () => {
    expect(checkMatrix({ size: 3, cells: [1, 2, 3, 4, 5, 6, 7, 8], unknown_index: 0 })).toBe(
      "matrix_cell_count",
    );
  });

  it("rejects an unknown cell outside the matrix", () => {
    expect(
      checkMatrix({ size: 2, cells: [1, 2, 3, 4], unknown_index: 4 }),
    ).toBe("unknown_index_out_of_range");
  });

  it("accepts a matrix whose cells and size agree", () => {
    expect(checkMatrix({ size: 2, cells: [1, 2, 3, 4], unknown_index: 3 })).toBeNull();
  });
});

describe("the analogy payload", () => {
  it("accepts two pair-cards with one unknown term", () => {
    expect(
      AnalogyPayloadSchema.safeParse({
        pairs: [
          { left: 2, right: 4 },
          { left: 5, right: 10 },
        ],
        unknown_index: 3,
      }).success,
    ).toBe(true);
  });

  it("rejects a third pair-card", () => {
    expect(
      AnalogyPayloadSchema.safeParse({
        pairs: [
          { left: 2, right: 4 },
          { left: 5, right: 10 },
          { left: 6, right: 12 },
        ],
        unknown_index: 0,
      }).success,
    ).toBe(false);
  });

  it("rejects an unknown term outside the four the two cards hold", () => {
    expect(
      checkAnalogy({
        pairs: [
          { left: 2, right: 4 },
          { left: 5, right: 10 },
        ],
        unknown_index: 4,
      }),
    ).toBe("unknown_index_out_of_range");
  });

  it("accepts an unknown term inside the two cards", () => {
    expect(
      checkAnalogy({
        pairs: [
          { left: 2, right: 4 },
          { left: 5, right: 10 },
        ],
        unknown_index: 3,
      }),
    ).toBeNull();
  });
});

describe("the hiddenOperation payload", () => {
  it("accepts a function machine with worked examples and a query", () => {
    expect(
      HiddenOperationPayloadSchema.safeParse({
        examples: [
          { input: 2, output: 7 },
          { input: 5, output: 16 },
        ],
        query_input: 9,
      }).success,
    ).toBe(true);
  });

  it("rejects a machine with a single example, which fixes no operation", () => {
    expect(
      HiddenOperationPayloadSchema.safeParse({
        examples: [{ input: 2, output: 7 }],
        query_input: 9,
      }).success,
    ).toBe(false);
  });

  it("rejects a query that repeats an example, whose answer is already shown", () => {
    expect(
      checkHiddenOperation({
        examples: [
          { input: 2, output: 7 },
          { input: 5, output: 16 },
        ],
        query_input: 5,
      }),
    ).toBe("query_repeats_example");
  });

  it("accepts a query the examples do not answer", () => {
    expect(
      checkHiddenOperation({
        examples: [
          { input: 2, output: 7 },
          { input: 5, output: 16 },
        ],
        query_input: 9,
      }),
    ).toBeNull();
  });
});

describe("the figurate payload", () => {
  it("accepts the four authored figures", () => {
    expect(
      FiguratePayloadSchema.safeParse({
        figures: [{ dots: 1 }, { dots: 3 }, { dots: 6 }, { dots: 10 }],
        unknown_index: 3,
      }).success,
    ).toBe(true);
  });

  it("rejects dot counts that do not grow", () => {
    expect(
      checkFigurate({ figures: [{ dots: 1 }, { dots: 3 }, { dots: 3 }], unknown_index: 2 }),
    ).toBe("figures_not_increasing");
  });

  it("rejects an unknown figure outside the sequence", () => {
    expect(
      checkFigurate({ figures: [{ dots: 1 }, { dots: 3 }, { dots: 6 }], unknown_index: 3 }),
    ).toBe("unknown_index_out_of_range");
  });

  it("accepts a growing sequence with its last figure unknown", () => {
    expect(
      checkFigurate({ figures: [{ dots: 1 }, { dots: 3 }, { dots: 6 }], unknown_index: 2 }),
    ).toBeNull();
  });
});

describe("parseStimulus", () => {
  it("routes each kind to its own payload schema", () => {
    expect(
      parseStimulus({ kind: "figurate", payload: { figures: [{ dots: 1 }], unknown_index: 0 } }),
    ).toBe("payload_shape");
  });

  it("reports the payload's own rejection tag, not a generic one", () => {
    expect(
      parseStimulus({
        kind: "numberSeries",
        payload: { terms: [2, 4, 8], unknown_index: 7 },
      }),
    ).toBe("unknown_index_out_of_range");
  });

  it("accepts a well-formed stimulus of every kind", () => {
    expect(parseStimulus({ kind: "matrix", payload: { size: 2, cells: [1, 2, 3, 4], unknown_index: 3 } }))
      .toBeNull();
  });

  it("rejects an envelope whose kind is not one of the six", () => {
    expect(parseStimulus({ kind: "wordProblem", payload: {} })).toBe("payload_shape");
  });
});

const TUTORIAL_STEPS = ["Llena cada fila con números distintos.", "Toca una celda y escribe."];
const REFERENCE_SHEET = ["Cada número aparece una sola vez por fila."];

describe("the puzzle envelope", () => {
  it("closes at the five puzzles the catalogue draws", () => {
    expect(PUZZLE_KINDS).toEqual(["kenken", "kakuro", "killer", "magicSquare", "wordSearch"]);
  });

  it("accepts a known kind with its tutorial and reference sheet", () => {
    expect(
      PuzzleEnvelopeSchema.safeParse({
        kind: "kenken",
        payload: { anything: 1 },
        tutorial_steps: TUTORIAL_STEPS,
        reference_sheet: REFERENCE_SHEET,
      }).success,
    ).toBe(true);
  });

  it("rejects a sixth puzzle kind", () => {
    expect(
      PuzzleEnvelopeSchema.safeParse({
        kind: "sudoku",
        payload: {},
        tutorial_steps: TUTORIAL_STEPS,
        reference_sheet: REFERENCE_SHEET,
      }).success,
    ).toBe(false);
  });

  it("rejects a puzzle that ships no tutorial, because it must play fully offline", () => {
    expect(
      PuzzleEnvelopeSchema.safeParse({
        kind: "kenken",
        payload: {},
        tutorial_steps: [],
        reference_sheet: REFERENCE_SHEET,
      }).success,
    ).toBe(false);
  });

  it("rejects a puzzle that ships no reference sheet", () => {
    expect(
      PuzzleEnvelopeSchema.safeParse({
        kind: "kenken",
        payload: {},
        tutorial_steps: TUTORIAL_STEPS,
        reference_sheet: [],
      }).success,
    ).toBe(false);
  });
});

const THREE_BY_THREE = {
  size: 3,
  blocked: [],
  given: [],
  solution: [
    [1, 2, 3],
    [2, 3, 1],
    [3, 1, 2],
  ],
};

describe("the board validators every puzzle shares", () => {
  it("rejects a blocked cell outside the board", () => {
    expect(checkBlockedCells({ ...THREE_BY_THREE, blocked: [{ row: 3, col: 0 }] })).toBe(
      "blocked_cell_outside_board",
    );
  });

  it("accepts a blocked cell inside the board", () => {
    expect(checkBlockedCells({ ...THREE_BY_THREE, blocked: [{ row: 2, col: 0 }] })).toBeNull();
  });

  it("rejects a solution with the wrong number of rows", () => {
    expect(
      checkSolutionShape({ size: 3, blocked: [], given: [], solution: [[1, 2, 3], [2, 3, 1]] }, 3),
    ).toBe("solution_shape");
  });

  it("rejects a solution value outside the board's digits", () => {
    expect(
      checkSolutionShape(
        { size: 3, blocked: [], given: [], solution: [[1, 2, 3], [2, 3, 1], [3, 1, 4]] },
        3,
      ),
    ).toBe("solution_shape");
  });

  it("rejects a blocked cell that carries a value in the solution", () => {
    expect(
      checkSolutionShape(
        {
          size: 3,
          blocked: [{ row: 0, col: 0 }],
          given: [],
          solution: [[1, 2, 3], [2, 3, 1], [3, 1, 2]],
        },
        3,
      ),
    ).toBe("solution_shape");
  });

  it("accepts a solution whose blocked cells are empty", () => {
    expect(
      checkSolutionShape(
        {
          size: 3,
          blocked: [{ row: 0, col: 0 }],
          given: [],
          solution: [[0, 2, 3], [2, 3, 1], [3, 1, 2]],
        },
        3,
      ),
    ).toBeNull();
  });

  it("rejects a printed cell outside the board", () => {
    expect(checkGivenCells({ ...THREE_BY_THREE, given: [{ row: 3, col: 0 }] })).toBe(
      "given_cell_outside_board",
    );
  });

  it("rejects a printed cell on a blocked square, which shows nothing", () => {
    expect(
      checkGivenCells({
        ...THREE_BY_THREE,
        blocked: [{ row: 0, col: 0 }],
        given: [{ row: 0, col: 0 }],
      }),
    ).toBe("given_cell_outside_board");
  });

  it("accepts a printed cell inside the board", () => {
    expect(checkGivenCells({ ...THREE_BY_THREE, given: [{ row: 1, col: 1 }] })).toBeNull();
  });

  it("rejects a run reaching outside the board", () => {
    expect(
      checkRunCoverage(THREE_BY_THREE, [{ cells: [{ row: 0, col: 3 }] }]),
    ).toBe("cage_cell_outside_board");
  });

  it("accepts runs that cross, so long as every fillable cell is in one", () => {
    expect(
      checkRunCoverage(THREE_BY_THREE, [
        { cells: THREE_BY_THREE.solution.flatMap((row, r) => row.map((_v, c) => ({ row: r, col: c }))) },
        { cells: [{ row: 0, col: 0 }] },
      ]),
    ).toBeNull();
  });

  it("rejects a cage reaching outside the board", () => {
    expect(
      checkCageCoverage(THREE_BY_THREE, [{ cells: [{ row: 0, col: 3 }] }]),
    ).toBe("cage_cell_outside_board");
  });

  it("rejects two cages claiming the same cell", () => {
    expect(
      checkCageCoverage(THREE_BY_THREE, [
        { cells: [{ row: 0, col: 0 }] },
        { cells: [{ row: 0, col: 0 }] },
      ]),
    ).toBe("cage_cells_overlap");
  });

  it("rejects cages that leave a fillable cell uncovered", () => {
    expect(checkCageCoverage(THREE_BY_THREE, [{ cells: [{ row: 0, col: 0 }] }])).toBe(
      "cage_coverage_incomplete",
    );
  });

  it("accepts cages that cover every fillable cell exactly once", () => {
    const cages = THREE_BY_THREE.solution.flatMap((row, rowIndex) =>
      row.map((_value, colIndex) => ({ cells: [{ row: rowIndex, col: colIndex }] })),
    );
    expect(checkCageCoverage(THREE_BY_THREE, cages)).toBeNull();
  });

  it("rejects a sum no selection of the board's digits can reach", () => {
    expect(checkSumReachable(2, 20, [1, 2, 3])).toBe("unreachable_target");
  });

  it("rejects a sum below the smallest the cage can hold", () => {
    expect(checkSumReachable(2, 2, [1, 2, 3])).toBe("unreachable_target");
  });

  it("accepts a sum the board's digits can reach", () => {
    expect(checkSumReachable(2, 5, [1, 2, 3])).toBeNull();
  });
});

const DIGITS_TO_THREE = [1, 2, 3];

function cage(cells: readonly [number, number][], target: number) {
  return {
    cells: cells.map(([row, col]) => ({ row, col })),
    rule: { kind: "sum", target, distinct: true } as const,
  };
}

function problemWith(cages: readonly ReturnType<typeof cage>[]): ConstraintProblem {
  return {
    board: THREE_BY_THREE,
    domain: DIGITS_TO_THREE,
    regions: [...latinRegions(THREE_BY_THREE), ...cages],
  };
}

const UNDER_CONSTRAINED = problemWith([
  cage([[0, 0], [0, 1], [0, 2]], 6),
  cage([[1, 0], [1, 1], [1, 2]], 6),
  cage([[2, 0], [2, 1], [2, 2]], 6),
]);

const PINNED = problemWith([
  cage([[0, 0]], 1),
  cage([[0, 1]], 2),
  cage([[0, 2]], 3),
  cage([[1, 0]], 2),
  cage([[1, 1], [1, 2]], 4),
  cage([[2, 0], [2, 1], [2, 2]], 6),
]);

/** Nine digits placed once each, every row and every column reaching 15. */
const LINE_SUMS: ConstraintProblem = {
  board: {
    size: 3,
    blocked: [],
    given: [],
    solution: [
      [2, 7, 6],
      [9, 5, 1],
      [4, 3, 8],
    ],
  },
  domain: [1, 2, 3, 4, 5, 6, 7, 8, 9],
  regions: [
    {
      cells: [0, 1, 2].flatMap((row) => [0, 1, 2].map((col) => ({ row, col }))),
      rule: { kind: "distinct" },
    },
    cage([[0, 0], [0, 1], [0, 2]], 15),
    cage([[1, 0], [1, 1], [1, 2]], 15),
    cage([[2, 0], [2, 1], [2, 2]], 15),
    cage([[0, 0], [1, 0], [2, 0]], 15),
    cage([[0, 1], [1, 1], [2, 1]], 15),
    cage([[0, 2], [1, 2], [2, 2]], 15),
  ],
};

function within(problem: ConstraintProblem, solutionLimit: number) {
  return searchSolutions(problem, { solutionLimit, nodeBudget: SEARCH_NODE_BUDGET });
}

describe("the uniqueness check", () => {
  it("counts every Latin square a rows-only constraint leaves open", () => {
    expect(within(UNDER_CONSTRAINED, 20)).toMatchObject({ kind: "counted", solutions: 12 });
  });

  it("stops counting at the limit it was given", () => {
    expect(within(UNDER_CONSTRAINED, 2)).toMatchObject({ kind: "counted", solutions: 2 });
  });

  it("rejects a board whose constraints admit more than one solution", () => {
    expect(checkUniqueSolution(UNDER_CONSTRAINED)).toBe("solution_not_unique");
  });

  it("accepts the fixed version of that board", () => {
    expect(checkUniqueSolution(PINNED)).toBeNull();
  });

  it("finds exactly one solution for the fixed board", () => {
    expect(within(PINNED, 20)).toMatchObject({ kind: "counted", solutions: 1 });
  });

  it("rejects a declared solution that is not the one the constraints force", () => {
    const wrong: ConstraintProblem = {
      ...PINNED,
      board: {
        ...THREE_BY_THREE,
        solution: [
          [1, 2, 3],
          [3, 1, 2],
          [2, 3, 1],
        ],
      },
    };
    expect(checkUniqueSolution(wrong)).toBe("solution_mismatch");
  });

  it("rejects a board no assignment satisfies", () => {
    const impossible: ConstraintProblem = problemWith([
      cage([[0, 0], [0, 1], [0, 2]], 7),
      cage([[1, 0], [1, 1], [1, 2]], 6),
      cage([[2, 0], [2, 1], [2, 2]], 6),
    ]);
    expect(checkUniqueSolution(impossible)).toBe("solution_mismatch");
  });
});

/** An order-5 magic square: every row and every column reaches 65. */
const MAGIC_FIVE = [
  [17, 24, 1, 8, 15],
  [23, 5, 7, 14, 16],
  [4, 6, 13, 20, 22],
  [10, 12, 19, 21, 3],
  [11, 18, 25, 2, 9],
];

function firstCells(count: number): { row: number; col: number }[] {
  return MAGIC_FIVE.flatMap((values, row) => values.map((_value, col) => ({ row, col }))).slice(
    0,
    count,
  );
}

function magicFiveWithGivens(count: number) {
  return {
    board: { size: 5, blocked: [], given: firstCells(count), solution: MAGIC_FIVE },
    row_targets: [65, 65, 65, 65, 65],
    column_targets: [65, 65, 65, 65, 65],
  };
}

describe("the search budget", () => {
  it("reports a board it cannot afford as a verdict rather than searching on", () => {
    expect(checkMagicSquare(magicFiveWithGivens(3))).toBe("search_budget_exhausted");
  });

  it("stops at the node budget it was given and says what it spent", () => {
    expect(searchSolutions(UNDER_CONSTRAINED, { solutionLimit: 20, nodeBudget: 10 })).toEqual({
      kind: "budgetExhausted",
      nodes: 10,
    });
  });

  it("keeps a verdict the last affordable node reached", () => {
    const spent = within(UNDER_CONSTRAINED, 2);
    expect(spent).toMatchObject({ kind: "counted", solutions: 2 });
    expect(
      searchSolutions(UNDER_CONSTRAINED, { solutionLimit: 2, nodeBudget: spent.nodes }),
    ).toEqual(spent);
  });

  it("gives up when the budget falls one node short of that verdict", () => {
    const spent = within(UNDER_CONSTRAINED, 2);
    expect(
      searchSolutions(UNDER_CONSTRAINED, { solutionLimit: 2, nodeBudget: spent.nodes - 1 }),
    ).toEqual({ kind: "budgetExhausted", nodes: spent.nodes - 1 });
  });

  /**
   * The exact cost is the only thing that separates strong pruning from weak
   * pruning; a green suite that never reads it stays green with a dead region
   * left to explore. `LINE_SUMS` is the board that reaches the boundary: two of
   * its nine digits already reach 15, so the third cell of that line can only
   * overshoot.
   */
  it("prunes a line the moment it can no longer be completed", () => {
    expect(within(LINE_SUMS, 100)).toEqual({ kind: "counted", solutions: 72, nodes: 16560 });
  });
});

/**
 * Every claim about what this solver can afford was tested at 3×3 until here,
 * while `BoardSchema` allows 6 and plan §5.3 D15 sets that as the ceiling. One
 * board of each kind at the ceiling is what stops the claim being a guess.
 */
const CYCLIC_SIX = [
  [1, 2, 3, 4, 5, 6],
  [2, 3, 4, 5, 6, 1],
  [3, 4, 5, 6, 1, 2],
  [4, 5, 6, 1, 2, 3],
  [5, 6, 1, 2, 3, 4],
  [6, 1, 2, 3, 4, 5],
];

const SIX_DIAGONAL = [0, 1, 2, 3, 4, 5].map((index) => ({ row: index, col: index }));

const LATIN_SIX_BOARD = { size: 6, blocked: [], given: SIX_DIAGONAL, solution: CYCLIC_SIX };

interface Domino {
  readonly cells: { row: number; col: number }[];
  readonly left: number;
  readonly right: number;
}

/** Three side-by-side pairs per row, which partitions the board into cages. */
function sixDominoes(): readonly Domino[] {
  const pairs: Domino[] = [];
  for (let row = 0; row < 6; row += 1) {
    for (let col = 0; col < 6; col += 2) {
      pairs.push({
        cells: [{ row, col }, { row, col: col + 1 }],
        left: CYCLIC_SIX[row]?.[col] ?? 0,
        right: CYCLIC_SIX[row]?.[col + 1] ?? 0,
      });
    }
  }
  return pairs;
}

const SIX_OPERATIONS = ["+", "-", "×"] as const;

function sixCage(pair: Domino, index: number) {
  const operation = SIX_OPERATIONS[index % SIX_OPERATIONS.length] ?? "+";
  switch (operation) {
    case "+":
      return { cells: pair.cells, operation, target: pair.left + pair.right };
    case "-":
      return { cells: pair.cells, operation, target: Math.abs(pair.left - pair.right) };
    case "×":
      return { cells: pair.cells, operation, target: pair.left * pair.right };
  }
}

const KENKEN_SIX: KenKenPayload = {
  board: LATIN_SIX_BOARD,
  cages: sixDominoes().map(sixCage),
};

const KILLER_SIX = {
  board: LATIN_SIX_BOARD,
  cages: sixDominoes().map((pair) => ({ cells: pair.cells, target: pair.left + pair.right })),
};

/** An order-6 magic square: thirty-six distinct numbers, every line reaching 111. */
const MAGIC_SIX = [
  [35, 1, 6, 26, 19, 24],
  [3, 32, 7, 21, 23, 25],
  [31, 9, 2, 22, 27, 20],
  [8, 28, 33, 17, 10, 15],
  [30, 5, 34, 12, 14, 16],
  [4, 36, 29, 13, 18, 11],
];

function magicSixLeavingBlank(isBlank: (row: number, col: number) => boolean) {
  const given: { row: number; col: number }[] = [];
  for (let row = 0; row < 6; row += 1) {
    for (let col = 0; col < 6; col += 1) {
      if (!isBlank(row, col)) {
        given.push({ row, col });
      }
    }
  }
  return {
    board: { size: 6, blocked: [], given, solution: MAGIC_SIX },
    row_targets: [111, 111, 111, 111, 111, 111],
    column_targets: [111, 111, 111, 111, 111, 111],
  };
}

/** Kakuro's clue cells run down the left edge and across the top; `0` is a wall. */
const KAKURO_SIX_SOLUTION = [
  [0, 0, 0, 0, 0, 0],
  [0, 1, 2, 3, 4, 5],
  [0, 2, 3, 4, 5, 6],
  [0, 3, 4, 0, 6, 7],
  [0, 4, 5, 6, 7, 8],
  [0, 5, 6, 7, 8, 9],
];

function kakuroSixBlocked(): { row: number; col: number }[] {
  const walls: { row: number; col: number }[] = [{ row: 3, col: 3 }];
  for (let col = 0; col < 6; col += 1) {
    walls.push({ row: 0, col });
  }
  for (let row = 1; row < 6; row += 1) {
    walls.push({ row, col: 0 });
  }
  return walls;
}

function acrossCells(row: number, from: number, to: number) {
  return Array.from({ length: to - from + 1 }, (_unused, offset) => ({ row, col: from + offset }));
}

function downCells(col: number, from: number, to: number) {
  return Array.from({ length: to - from + 1 }, (_unused, offset) => ({ row: from + offset, col }));
}

/** A run's clue is the sum of the cells it covers, read off the solution. */
function run(cells: { row: number; col: number }[]) {
  return {
    cells,
    sum: cells.reduce(
      (total, cell) => total + (KAKURO_SIX_SOLUTION[cell.row]?.[cell.col] ?? 0),
      0,
    ),
  };
}

const KAKURO_SIX = {
  board: {
    size: 6,
    blocked: kakuroSixBlocked(),
    given: [...acrossCells(1, 1, 5), ...acrossCells(2, 1, 2)],
    solution: KAKURO_SIX_SOLUTION,
  },
  runs: [
    run(acrossCells(1, 1, 5)),
    run(acrossCells(2, 1, 5)),
    run(acrossCells(3, 1, 2)),
    run(acrossCells(3, 4, 5)),
    run(acrossCells(4, 1, 5)),
    run(acrossCells(5, 1, 5)),
    run(downCells(1, 1, 5)),
    run(downCells(2, 1, 5)),
    run(downCells(3, 1, 2)),
    run(downCells(3, 4, 5)),
    run(downCells(4, 1, 5)),
    run(downCells(5, 1, 5)),
  ],
};

const WORD_SEARCH_SIX = {
  grid: [
    ["S", "U", "M", "A", "B", "C"],
    ["D", "R", "E", "S", "T", "A"],
    ["F", "G", "H", "I", "J", "K"],
    ["C", "E", "R", "O", "L", "M"],
    ["N", "P", "Q", "T", "V", "W"],
    ["X", "Y", "Z", "Ñ", "A", "B"],
  ],
  words: ["SUMA", "RESTA", "CERO"],
};

describe("the 6×6 ceiling every kind has to afford", () => {
  it("accepts a kenken whose eighteen cages add, subtract and multiply", () => {
    expect(KenKenPayloadSchema.safeParse(KENKEN_SIX).success).toBe(true);
    expect(checkKenKen(KENKEN_SIX)).toBeNull();
  });

  it("accepts a killer whose eighteen cages carry sums", () => {
    expect(KillerPayloadSchema.safeParse(KILLER_SIX).success).toBe(true);
    expect(checkKiller(KILLER_SIX)).toBeNull();
  });

  it("accepts a kakuro whose runs are broken by an interior wall", () => {
    expect(KakuroPayloadSchema.safeParse(KAKURO_SIX).success).toBe(true);
    expect(checkKakuro(KAKURO_SIX)).toBeNull();
  });

  it("accepts a magic square drawing on thirty-six numbers", () => {
    const payload = magicSixLeavingBlank((row, col) => row === col);
    expect(MagicSquarePayloadSchema.safeParse(payload).success).toBe(true);
    expect(checkMagicSquare(payload)).toBeNull();
  });

  it("accepts a word search on a 6×6 grid", () => {
    expect(WordSearchPayloadSchema.safeParse(WORD_SEARCH_SIX).success).toBe(true);
    expect(checkWordSearch(WORD_SEARCH_SIX)).toBeNull();
  });

  it("reports that same magic square as unaffordable once both diagonals are blank", () => {
    expect(
      checkMagicSquare(magicSixLeavingBlank((row, col) => row === col || row + col === 5)),
    ).toBe("search_budget_exhausted");
  });
});

const LATIN_THREE = [
  [1, 2, 3],
  [2, 3, 1],
  [3, 1, 2],
];

const KENKEN_PAYLOAD: KenKenPayload = {
  board: { size: 3, blocked: [], given: [], solution: LATIN_THREE },
  cages: [
    { cells: [{ row: 0, col: 0 }, { row: 1, col: 0 }], operation: "+", target: 3 },
    { cells: [{ row: 0, col: 1 }, { row: 0, col: 2 }], operation: "-", target: 1 },
    { cells: [{ row: 1, col: 1 }, { row: 2, col: 1 }], operation: "-", target: 2 },
    { cells: [{ row: 1, col: 2 }, { row: 2, col: 2 }], operation: "+", target: 3 },
    { cells: [{ row: 2, col: 0 }], operation: "+", target: 3 },
  ],
};

const KILLER_PAYLOAD = {
  board: { size: 3, blocked: [], given: [], solution: LATIN_THREE },
  cages: [
    { cells: [{ row: 0, col: 0 }], target: 1 },
    { cells: [{ row: 0, col: 1 }], target: 2 },
    { cells: [{ row: 0, col: 2 }], target: 3 },
    { cells: [{ row: 1, col: 0 }], target: 2 },
    { cells: [{ row: 1, col: 1 }, { row: 1, col: 2 }], target: 4 },
    { cells: [{ row: 2, col: 0 }, { row: 2, col: 1 }, { row: 2, col: 2 }], target: 6 },
  ],
};

const KAKURO_PAYLOAD = {
  board: {
    size: 3,
    blocked: [{ row: 0, col: 0 }],
    given: [{ row: 1, col: 0 }, { row: 1, col: 1 }],
    solution: [
      [0, 1, 3],
      [4, 2, 9],
      [6, 8, 5],
    ],
  },
  runs: [
    { cells: [{ row: 0, col: 1 }, { row: 0, col: 2 }], sum: 4 },
    { cells: [{ row: 1, col: 0 }, { row: 1, col: 1 }, { row: 1, col: 2 }], sum: 15 },
    { cells: [{ row: 2, col: 0 }, { row: 2, col: 1 }, { row: 2, col: 2 }], sum: 19 },
    { cells: [{ row: 1, col: 0 }, { row: 2, col: 0 }], sum: 10 },
    { cells: [{ row: 0, col: 1 }, { row: 1, col: 1 }, { row: 2, col: 1 }], sum: 11 },
    { cells: [{ row: 0, col: 2 }, { row: 1, col: 2 }, { row: 2, col: 2 }], sum: 17 },
  ],
};

describe("the kenken payload", () => {
  it("accepts a 3×3 board whose cages force one solution", () => {
    expect(KenKenPayloadSchema.safeParse(KENKEN_PAYLOAD).success).toBe(true);
    expect(checkKenKen(KENKEN_PAYLOAD)).toBeNull();
  });

  it("rejects a cage that leaves a cell uncovered", () => {
    expect(
      checkKenKen({ ...KENKEN_PAYLOAD, cages: KENKEN_PAYLOAD.cages.slice(0, 4) }),
    ).toBe("cage_coverage_incomplete");
  });

  it("rejects a board whose cages stop forcing one solution", () => {
    expect(
      checkKenKen({
        ...KENKEN_PAYLOAD,
        cages: [
          { cells: [{ row: 0, col: 0 }, { row: 0, col: 1 }, { row: 0, col: 2 }], operation: "+" as const, target: 6 },
          { cells: [{ row: 1, col: 0 }, { row: 1, col: 1 }, { row: 1, col: 2 }], operation: "+" as const, target: 6 },
          { cells: [{ row: 2, col: 0 }, { row: 2, col: 1 }, { row: 2, col: 2 }], operation: "+" as const, target: 6 },
        ],
      }),
    ).toBe("solution_not_unique");
  });

  it("rejects a fifth cage operation", () => {
    expect(
      KenKenPayloadSchema.safeParse({
        ...KENKEN_PAYLOAD,
        cages: [{ cells: [{ row: 0, col: 0 }], operation: "^", target: 3 }],
      }).success,
    ).toBe(false);
  });
});

describe("the kenken cage operations", () => {
  const multiplyAndDivide: KenKenPayload = {
    board: { size: 3, blocked: [], given: [], solution: LATIN_THREE },
    cages: [
      { cells: [{ row: 0, col: 0 }], operation: "+", target: 1 },
      { cells: [{ row: 0, col: 1 }, { row: 0, col: 2 }], operation: "×", target: 6 },
      { cells: [{ row: 1, col: 0 }, { row: 1, col: 1 }], operation: "+", target: 5 },
      { cells: [{ row: 1, col: 2 }, { row: 2, col: 2 }], operation: "÷", target: 2 },
      { cells: [{ row: 2, col: 0 }, { row: 2, col: 1 }], operation: "-", target: 2 },
    ],
  };

  it("accepts a board whose cages multiply and divide", () => {
    expect(checkKenKen(multiplyAndDivide)).toBeNull();
  });

  it("rejects a subtracting or dividing cage that is not exactly two cells", () => {
    expect(
      checkKenKen({
        ...multiplyAndDivide,
        cages: multiplyAndDivide.cages.map((cage, index) =>
          index === 0 ? { ...cage, operation: "÷" as const } : cage,
        ),
      }),
    ).toBe("binary_cage_size");
  });

  it("rejects a multiplying cage whose product is not its target", () => {
    expect(
      checkKenKen({
        ...multiplyAndDivide,
        cages: multiplyAndDivide.cages.map((cage, index) =>
          index === 1 ? { ...cage, target: 7 } : cage,
        ),
      }),
    ).toBe("solution_mismatch");
  });

  it("rejects a dividing cage whose quotient is not its target", () => {
    expect(
      checkKenKen({
        ...multiplyAndDivide,
        cages: multiplyAndDivide.cages.map((cage, index) =>
          index === 3 ? { ...cage, target: 4 } : cage,
        ),
      }),
    ).toBe("solution_mismatch");
  });
});

describe("the killer payload", () => {
  it("accepts a 3×3 board whose sums force one solution", () => {
    expect(KillerPayloadSchema.safeParse(KILLER_PAYLOAD).success).toBe(true);
    expect(checkKiller(KILLER_PAYLOAD)).toBeNull();
  });

  it("rejects a cage sum no selection of the board's digits can reach", () => {
    expect(
      checkKiller({
        ...KILLER_PAYLOAD,
        cages: [
          { cells: [{ row: 0, col: 0 }], target: 1 },
          { cells: [{ row: 0, col: 1 }], target: 2 },
          { cells: [{ row: 0, col: 2 }], target: 3 },
          { cells: [{ row: 1, col: 0 }], target: 2 },
          { cells: [{ row: 1, col: 1 }, { row: 1, col: 2 }], target: 12 },
          { cells: [{ row: 2, col: 0 }, { row: 2, col: 1 }, { row: 2, col: 2 }], target: 6 },
        ],
      }),
    ).toBe("unreachable_target");
  });

  it("rejects a declared solution the cages do not produce", () => {
    expect(
      checkKiller({
        ...KILLER_PAYLOAD,
        board: {
          ...KILLER_PAYLOAD.board,
          solution: [
            [1, 2, 3],
            [3, 1, 2],
            [2, 3, 1],
          ],
        },
      }),
    ).toBe("solution_mismatch");
  });
});

describe("the kakuro payload", () => {
  it("accepts a board whose runs and printed cells force one solution", () => {
    expect(KakuroPayloadSchema.safeParse(KAKURO_PAYLOAD).success).toBe(true);
    expect(checkKakuro(KAKURO_PAYLOAD)).toBeNull();
  });

  it("rejects a board that stops forcing one solution when a printed cell is removed", () => {
    expect(
      checkKakuro({
        ...KAKURO_PAYLOAD,
        board: { ...KAKURO_PAYLOAD.board, given: [{ row: 1, col: 0 }] },
      }),
    ).toBe("solution_not_unique");
  });

  it("rejects a run that leaves a fillable cell in no run at all", () => {
    expect(
      checkKakuro({ ...KAKURO_PAYLOAD, runs: KAKURO_PAYLOAD.runs.slice(0, 1) }),
    ).toBe("cage_coverage_incomplete");
  });

  it("rejects a run sum nine distinct digits cannot reach", () => {
    expect(
      checkKakuro({
        ...KAKURO_PAYLOAD,
        runs: [{ cells: [{ row: 0, col: 1 }, { row: 0, col: 2 }], sum: 18 }, ...KAKURO_PAYLOAD.runs.slice(1)],
      }),
    ).toBe("unreachable_target");
  });
});

const MAGIC_SQUARE_PAYLOAD = {
  board: {
    size: 3,
    blocked: [],
    given: [{ row: 0, col: 0 }, { row: 0, col: 1 }, { row: 1, col: 0 }],
    solution: [
      [2, 7, 6],
      [9, 5, 1],
      [4, 3, 8],
    ],
  },
  row_targets: [15, 15, 15],
  column_targets: [15, 15, 15],
};

const WORD_SEARCH_PAYLOAD = {
  grid: [
    ["S", "U", "M", "A", "X"],
    ["C", "Y", "Z", "W", "B"],
    ["E", "D", "F", "G", "H"],
    ["R", "I", "J", "K", "L"],
    ["O", "N", "P", "Q", "T"],
  ],
  words: ["SUMA", "CERO"],
};

describe("the magicSquare payload", () => {
  it("accepts a square whose targets and printed cells force one solution", () => {
    expect(MagicSquarePayloadSchema.safeParse(MAGIC_SQUARE_PAYLOAD).success).toBe(true);
    expect(checkMagicSquare(MAGIC_SQUARE_PAYLOAD)).toBeNull();
  });

  it("rejects a square with one printed cell too few to force a solution", () => {
    expect(
      checkMagicSquare({
        ...MAGIC_SQUARE_PAYLOAD,
        board: {
          ...MAGIC_SQUARE_PAYLOAD.board,
          given: [{ row: 0, col: 0 }, { row: 0, col: 1 }],
        },
      }),
    ).toBe("solution_not_unique");
  });

  it("rejects one target more than the board has rows", () => {
    const extraTarget = { ...MAGIC_SQUARE_PAYLOAD, row_targets: [15, 15, 15, 15] };
    expect(MagicSquarePayloadSchema.safeParse(extraTarget).success).toBe(true);
    expect(checkMagicSquare(extraTarget)).toBe("solution_shape");
  });
});

describe("the wordSearch payload", () => {
  it("accepts a grid holding each word exactly once", () => {
    expect(WordSearchPayloadSchema.safeParse(WORD_SEARCH_PAYLOAD).success).toBe(true);
    expect(checkWordSearch(WORD_SEARCH_PAYLOAD)).toBeNull();
  });

  it("rejects a word the grid does not hold", () => {
    expect(checkWordSearch({ ...WORD_SEARCH_PAYLOAD, words: ["RESTA"] })).toBe("word_not_found");
  });

  it("rejects a word the grid holds twice", () => {
    expect(
      checkWordSearch({
        grid: [
          ["D", "O", "S"],
          ["X", "Y", "Z"],
          ["D", "O", "S"],
        ],
        words: ["DOS"],
      }),
    ).toBe("word_occurs_twice");
  });

  it("rejects a ragged grid", () => {
    const ragged = {
      grid: [["A", "B", "C"], ["D", "E"], ["F", "G", "H"]],
      words: ["ABC"],
    };
    expect(WordSearchPayloadSchema.safeParse(ragged).success).toBe(true);
    expect(checkWordSearch(ragged)).toBe("solution_shape");
  });
});

describe("parsePuzzle", () => {
  it("routes each kind to its own payload schema", () => {
    expect(
      parsePuzzle({
        kind: "wordSearch",
        payload: WORD_SEARCH_PAYLOAD,
        tutorial_steps: TUTORIAL_STEPS,
        reference_sheet: REFERENCE_SHEET,
      }),
    ).toBeNull();
  });

  it("reports the payload's own rejection tag", () => {
    expect(
      parsePuzzle({
        kind: "wordSearch",
        payload: { ...WORD_SEARCH_PAYLOAD, words: ["RESTA"] },
        tutorial_steps: TUTORIAL_STEPS,
        reference_sheet: REFERENCE_SHEET,
      }),
    ).toBe("word_not_found");
  });

  it("rejects a kind that is not one of the five", () => {
    expect(
      parsePuzzle({
        kind: "sudoku",
        payload: {},
        tutorial_steps: TUTORIAL_STEPS,
        reference_sheet: REFERENCE_SHEET,
      }),
    ).toBe("payload_shape");
  });
});

interface RejectionRow {
  readonly expected_tag: string;
  readonly pack: unknown;
}

describe("the committed golden fixtures", () => {
  it("holds a golden fixture for each of the six stimulus kinds", () => {
    expect(goldenStems("stimulus")).toEqual([...STIMULUS_KINDS].sort());
  });

  it("holds a golden fixture for each of the five puzzle kinds", () => {
    expect(goldenStems("puzzle")).toEqual([...PUZZLE_KINDS].sort());
  });

  it("parses every golden stimulus fixture", () => {
    for (const kind of STIMULUS_KINDS) {
      expect(parsePack(readFixture(`stimulus/${kind}.json`))).toMatchObject({ ok: true });
    }
  });

  it("parses every golden puzzle fixture", () => {
    for (const kind of PUZZLE_KINDS) {
      expect(parsePack(readFixture(`puzzle/${kind}.json`))).toMatchObject({ ok: true });
    }
  });

  it("rejects every rejection row with the tag that row declares", () => {
    for (const group of ["stimulus", "puzzle"] as const) {
      for (const stem of goldenStems(group)) {
        const row = readFixture(`${group}/${stem}.rejected.json`) as RejectionRow;
        expect({ stem, result: parsePack(row.pack) }).toEqual({
          stem,
          result: { ok: false, tag: row.expected_tag },
        });
      }
    }
  });

  it("parses the item that carries a filled diagnosis and the item that carries none", () => {
    expect(parsePack(readFixture("diagnosis/filled.json"))).toMatchObject({ ok: true });
    expect(parsePack(readFixture("diagnosis/empty.json"))).toMatchObject({ ok: true });
  });
});
