import { PuzzleEnvelopeSchema, type PuzzleEnvelope } from "@akimath/contract";

/**
 * Authored puzzles, read from a file.
 *
 * **PURE** — text in, envelopes out. Reading the file is the CLI's.
 *
 * They are validated here against the frozen envelope and again by `parsePack`
 * once the pack is assembled, which is not redundant: this one names the
 * puzzle, and `parsePack`'s tag names only the fault. A board a person authored
 * by hand is exactly the input where knowing *which* one is wrong saves the
 * afternoon.
 */
export function readPuzzleFile(text: string): readonly PuzzleEnvelope[] {
  const parsed: unknown = JSON.parse(text);
  if (typeof parsed !== "object" || parsed === null) {
    throw new TypeError("puzzle file: not an object");
  }
  const list = (parsed as { puzzles?: unknown }).puzzles;
  if (!Array.isArray(list) || list.length === 0) {
    throw new TypeError("puzzle file: puzzles must be a non-empty array");
  }

  return list.map((raw, index) => {
    const result = PuzzleEnvelopeSchema.safeParse(raw);
    if (!result.success) {
      throw new TypeError(
        `puzzle file: puzzle ${index} is malformed — ${result.error.issues[0]?.message ?? ""}`,
      );
    }
    return result.data;
  });
}
