import { drawsFrom, shuffledIndices } from "./draw.js";

/**
 * A seeded Latin square.
 *
 * **PURE.** Seed and size in, rows out. No clock, no ambient randomness — the
 * same bar the rederivation machine meets, and for the same reason: a batch
 * that cannot be reproduced cannot be reviewed or regenerated after an edit.
 *
 * **It starts cyclic and is then shuffled** (design D3). `((r + c) mod n) + 1`
 * is a Latin square in one line, but used alone every KenKen in the pack is the
 * same puzzle wearing different cages, and once a player sees the diagonal they
 * cannot unsee it. Rows, columns and symbols are each permuted.
 *
 * **This does not sample uniformly from all Latin squares**, and does not claim
 * to: it samples from the `(n!)³` orbit of the cyclic square, which at these
 * sizes is far more variety than a pack will ever hold. The limit is stated
 * because a comment claiming uniformity would be the defect.
 */
export function latinSquare(seed: bigint, size: number): readonly (readonly number[])[] {
  if (size < 3) {
    throw new RangeError(`a Latin square below 3 is not a board: ${size}`);
  }

  const draw = drawsFrom(seed);

  const rowOrder = shuffledIndices(size, draw);
  const columnOrder = shuffledIndices(size, draw);
  const symbols = shuffledIndices(size, draw);

  return rowOrder.map((r) =>
    columnOrder.map((c) => symbols[(r + c) % size]! + 1),
  );
}
