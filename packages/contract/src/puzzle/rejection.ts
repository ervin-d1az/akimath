/** Every way a puzzle can be unplayable. Stable, and closed. */
export type PuzzleRejectionTag =
  | "payload_shape"
  | "blocked_cell_outside_board"
  | "given_cell_outside_board"
  | "cage_cell_outside_board"
  | "cage_cells_overlap"
  | "cage_coverage_incomplete"
  | "unreachable_target"
  | "binary_cage_size"
  | "solution_shape"
  | "solution_not_unique"
  | "solution_mismatch"
  | "search_budget_exhausted"
  | "word_not_found"
  | "word_occurs_twice";
